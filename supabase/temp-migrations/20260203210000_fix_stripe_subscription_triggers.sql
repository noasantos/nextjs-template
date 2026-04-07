-- Migração para consertar triggers do Stripe Sync Engine
-- 
-- CONTEXT:
-- A tabela psychologist_onboarding_state serve para:
-- - current_step: rastrear progresso do wizard de onboarding (1-6 passos)
-- - draft_data: salvar rascunho dos dados entre etapas
-- - onboarding_completed_at: marcar quando o wizard foi finalizado
--
-- Onboarding (wizard) é SEPARADO do pagamento/plano!
-- - Onboarding completo = psychologists.onboarding_completed = true
-- - Plano ativo = subscription_status = 'active'|'trialing'

-- 1. Adicionar coluna onboarding_completed_at que está faltando
-- (o código em save-onboarding.ts tenta usar essa coluna mas ela não existe)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'psychologist_onboarding_state' 
        AND column_name = 'onboarding_completed_at'
    ) THEN
        ALTER TABLE public.psychologist_onboarding_state 
        ADD COLUMN onboarding_completed_at timestamp with time zone;
        
        RAISE NOTICE 'Coluna onboarding_completed_at adicionada';
    END IF;
END $$;
-- 2. Atualizar os tipos do TypeScript (gerar novamente após aplicar)
-- pnpm supabase:generate-types

-- 3. Remover triggers duplicados que usam lógica antiga por customer_id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'stripe' AND c.relname = 'subscriptions'
    ) THEN
        DROP TRIGGER IF EXISTS on_stripe_subscription_sync ON stripe.subscriptions;
        DROP TRIGGER IF EXISTS on_stripe_subscription_auth_sync ON stripe.subscriptions;
    END IF;
END $$;
-- 4. Remover funções duplicadas (mantemos apenas handle_stripe_subscription_update)
DROP FUNCTION IF EXISTS public.sync_stripe_subscription_to_psychologist();
DROP FUNCTION IF EXISTS public.sync_stripe_subscription_to_auth_claims();
-- 5. Recriar a função principal que atualiza APENAS subscription (NÃO onboarding!)
-- Onboarding é completado pelo wizard em completeOnboarding(), não pelo pagamento
CREATE OR REPLACE FUNCTION public.handle_stripe_subscription_update()
RETURNS TRIGGER AS $$
DECLARE
    v_psychologist_id UUID;
BEGIN
    -- Buscar psychologist_id dos metadados (inserido no checkout)
    v_psychologist_id := (NEW.metadata->>'psychologist_id')::UUID;
    
    -- Se não encontrou nos metadados, tenta pelo stripe_customer_id
    IF v_psychologist_id IS NULL THEN
        SELECT id INTO v_psychologist_id
        FROM public.psychologists
        WHERE stripe_customer_id = NEW.customer;
    END IF;

    IF v_psychologist_id IS NOT NULL THEN
        -- Atualiza apenas dados da assinatura (NÃO onboarding!)
        UPDATE public.psychologists
        SET 
            subscription_status = NEW.status,
            stripe_subscription_id = NEW.id,
            updated_at = NOW()
        WHERE id = v_psychologist_id;
        
        -- Atualiza auth claims para o JWT ter subscription_status atualizado
        UPDATE auth.users
        SET raw_app_meta_data = jsonb_set(
            COALESCE(raw_app_meta_data, '{}'::jsonb),
            '{subscription_status}',
            to_jsonb(NEW.status)
        ),
        updated_at = NOW()
        WHERE id = v_psychologist_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- 6. Recriar o trigger para disparar em INSERT e UPDATE
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'stripe' AND c.relname = 'subscriptions'
    ) THEN
        DROP TRIGGER IF EXISTS on_stripe_subscription_update ON stripe.subscriptions;
        CREATE TRIGGER on_stripe_subscription_update
            AFTER INSERT OR UPDATE ON stripe.subscriptions
            FOR EACH ROW
            EXECUTE FUNCTION public.handle_stripe_subscription_update();
    END IF;
END $$;
-- 7. Comentários
COMMENT ON FUNCTION public.handle_stripe_subscription_update() IS 
'Atualiza subscription_status e stripe_subscription_id em psychologists quando o Stripe Sync Engine sincroniza. 
IMPORTANTE: Não atualiza onboarding_completed - onboarding é completado pelo wizard em completeOnboarding(), não pelo pagamento.';
COMMENT ON COLUMN public.psychologist_onboarding_state.onboarding_completed_at IS 
'Data/hora em que o usuário completou o wizard de onboarding (6 passos). 
Preenchido por completeOnboarding(), não pelo trigger de subscription.';
