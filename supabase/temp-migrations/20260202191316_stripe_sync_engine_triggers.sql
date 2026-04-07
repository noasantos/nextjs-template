-- Migração para adicionar triggers de sincronização do Stripe Sync Engine
-- Este trigger observa a tabela stripe.subscriptions e atualiza public.psychologists

-- 1. Garantir que a coluna stripe_subscription_id existe em public.psychologists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologists' AND column_name = 'stripe_subscription_id') THEN
        ALTER TABLE public.psychologists ADD COLUMN stripe_subscription_id TEXT;
    END IF;
END $$;
-- 2. Função para lidar com atualizações de assinatura do Stripe
CREATE OR REPLACE FUNCTION public.handle_stripe_subscription_update()
RETURNS TRIGGER AS $$
DECLARE
    v_psychologist_id UUID;
BEGIN
    -- O Stripe Sync Engine armazena metadados no campo 'metadata' (JSONB)
    -- Esperamos que o psychologist_id esteja lá
    v_psychologist_id := (NEW.metadata->>'psychologist_id')::UUID;

    IF v_psychologist_id IS NOT NULL THEN
        UPDATE public.psychologists
        SET 
            subscription_status = NEW.status,
            stripe_subscription_id = NEW.id,
            updated_at = NOW()
        WHERE id = v_psychologist_id;
        
        -- Também atualizamos o estado de onboarding se a assinatura estiver ativa
        IF NEW.status = 'active' OR NEW.status = 'trialing' THEN
            UPDATE public.psychologist_onboarding_state
            SET 
                onboarding_completed_at = COALESCE(onboarding_completed_at, NOW()),
                updated_at = NOW()
            WHERE psychologist_id = v_psychologist_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- 3. Criar o trigger na tabela stripe.subscriptions
-- Nota: O esquema 'stripe' é o padrão usado pelo Stripe Sync Engine
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
-- 4. Comentários para documentação
COMMENT ON FUNCTION public.handle_stripe_subscription_update() IS 'Sincroniza o status da assinatura do Stripe com a tabela de psicólogos usando o Stripe Sync Engine.';
