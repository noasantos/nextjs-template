-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T12:02:21Z

-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T10:29:34Z

-- =====================================================
-- FIX V2: Correção da Fase 1 (Essencial) do Onboarding
-- =====================================================
-- Fase 1 (Essencial/Pré-App) = TODOS os passos abaixo devem estar completos:
--   1. Identity: nome, sobrenome, telefone, data nascimento
--   2. Professional: CPF, CRP, estado CRP, documento CRP
--   3. Payment: assinatura ativa (active/trialing) OU payment_step_completed
--
-- Apenas quando TODOS esses 3 estiverem completos, o usuário pode acessar o app.
--
-- Fase 2 (Completo/In-App):
--   4. Configuration (formerly Readiness): disponibilidade, serviços
--   5. Profile: bio, foto, perfil público
--
-- NOTA: Os nomes das colunas permanecem os mesmos para compatibilidade,
-- mas a lógica de "essential_complete" agora verifica identity + professional + payment

-- =====================================================
-- 1. Atualizar VIEW para calcular essential_complete corretamente
-- =====================================================

DROP VIEW IF EXISTS public.psychologist_onboarding_summary;
CREATE VIEW public.psychologist_onboarding_summary AS
SELECT 
  pos.psychologist_id,
  pos.payment_step_completed,
  pos.identity_step_completed,
  pos.professional_step_completed,
  pos.readiness_step_completed,
  pos.profile_step_completed,
  pos.current_step,
  pos.total_steps,
  pos.completion_percentage,
  pos.onboarding_completed_at,
  pos.last_resumed_at,
  pos.abandoned_at,
  -- FASE 1 (ESSENCIAL): identity + professional + (payment OU subscription ativa)
  -- Todos devem estar completos para liberar acesso ao app
  (
    pos.identity_step_completed 
    AND pos.professional_step_completed 
    AND (
      COALESCE(up.subscription_status = ANY (ARRAY['active'::text, 'trialing'::text]), false) 
      OR pos.payment_step_completed
    )
  ) AS essential_complete,
  -- FASE 2 (COMPLETO): todos os 5 passos OU onboarding_completed_at preenchido
  (
    pos.onboarding_completed_at IS NOT NULL 
    OR (
      pos.payment_step_completed 
      AND pos.identity_step_completed 
      AND pos.professional_step_completed 
      AND pos.readiness_step_completed 
      AND pos.profile_step_completed
    )
  ) AS fully_complete,
  -- Próximo passo pendente
  CASE
    WHEN pos.onboarding_completed_at IS NOT NULL THEN NULL::text
    WHEN NOT pos.identity_step_completed THEN 'identity'::text
    WHEN NOT pos.professional_step_completed THEN 'professional'::text
    WHEN NOT (
      COALESCE(up.subscription_status = ANY (ARRAY['active'::text, 'trialing'::text]), false) 
      OR pos.payment_step_completed
    ) THEN 'subscription'::text
    WHEN NOT pos.readiness_step_completed THEN 'readiness'::text
    WHEN NOT pos.profile_step_completed THEN 'profile'::text
    ELSE NULL::text
  END AS next_pending_step,
  up.subscription_status
FROM psychologist_onboarding_state pos
LEFT JOIN user_psychologists up ON up.id = pos.psychologist_id;
COMMENT ON VIEW public.psychologist_onboarding_summary IS 
'View consolidada do progresso de onboarding.
- essential_complete: Fase 1 completa (identity + professional + payment/subscription)
- fully_complete: Fase 2 completa (todos os 5 passos)
- next_pending_step: Próximo passo que o usuário precisa completar';
-- =====================================================
-- 2. Atualizar função is_onboarding_essential_complete
-- =====================================================

CREATE OR REPLACE FUNCTION public.is_onboarding_essential_complete(p_psychologist_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_has_subscription BOOLEAN;
  v_state RECORD;
BEGIN
  -- Buscar estado do onboarding
  SELECT * INTO v_state 
  FROM public.psychologist_onboarding_state 
  WHERE psychologist_id = p_psychologist_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Verificar se tem subscription ativa
  SELECT subscription_status IN ('active', 'trialing')
  INTO v_has_subscription
  FROM public.user_psychologists
  WHERE id = p_psychologist_id;
  
  -- FASE 1 (ESSENCIAL): identity + professional + (payment OU subscription)
  RETURN (
    v_state.identity_step_completed 
    AND v_state.professional_step_completed 
    AND (COALESCE(v_has_subscription, FALSE) OR v_state.payment_step_completed)
  );
END;
$$;
COMMENT ON FUNCTION public.is_onboarding_essential_complete(UUID) IS 
'Verifica se Fase 1 (Essencial) está completa: identity + professional + payment/subscription.
Retorna TRUE apenas quando TODOS os 3 componentes essenciais estão completos.';
-- =====================================================
-- 3. Atualizar função get_onboarding_status_by_user
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_onboarding_status_by_user(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  p_role public.app_role;
  p_essential_complete boolean;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN false;
  END IF;
  
  -- Check user role
  SELECT role INTO p_role
  FROM public.user_roles
  WHERE user_id = p_user_id;
  
  -- Non-psychologists don't have onboarding flow
  IF p_role IS NULL OR p_role != 'psychologist' THEN
    RETURN true;
  END IF;
  
  -- Verificar Fase 1 (Essencial) usando a view atualizada
  SELECT essential_complete INTO p_essential_complete
  FROM public.psychologist_onboarding_summary
  WHERE psychologist_id = p_user_id;
  
  -- Return status, defaulting to false if NULL
  RETURN COALESCE(p_essential_complete, false);
END;
$function$;
COMMENT ON FUNCTION public.get_onboarding_status_by_user(UUID) IS 
'Verifica se o usuário completou a Fase 1 (Essencial) do onboarding.
Fase 1 = identity + professional + (payment OU subscription ativa).
Retorna TRUE apenas quando todos os componentes essenciais estão prontos.';
-- =====================================================
-- 4. Atualizar trigger de sync para usar essential_complete correto
-- =====================================================

CREATE OR REPLACE FUNCTION public.sync_onboarding_completed_with_essential()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_essential_complete BOOLEAN;
BEGIN
  -- Verificar se Fase 1 está completa usando a view atualizada
  SELECT essential_complete INTO v_essential_complete
  FROM public.psychologist_onboarding_summary
  WHERE psychologist_id = NEW.id;
  
  -- Sincronizar onboarding_completed com essential_complete
  IF v_essential_complete AND NOT COALESCE(NEW.onboarding_completed, FALSE) THEN
    NEW.onboarding_completed := TRUE;
    NEW.updated_at := NOW();
  END IF;
  
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.sync_onboarding_completed_with_essential() IS 
'Trigger function: sincroniza onboarding_completed com essential_complete (Fase 1).
Marca onboarding_completed = TRUE quando identity + professional + payment estão completos.';
-- Recriar trigger
DROP TRIGGER IF EXISTS trg_sync_onboarding_completed ON public.user_psychologists;
CREATE TRIGGER trg_sync_onboarding_completed
  BEFORE UPDATE OF subscription_status ON public.user_psychologists
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_onboarding_completed_with_essential();
-- =====================================================
-- 5. Recalcular progresso para todos os usuários
-- =====================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT psychologist_id FROM public.psychologist_onboarding_state
  LOOP
    PERFORM public.calculate_onboarding_progress(r.psychologist_id);
  END LOOP;
END $$;
-- =====================================================
-- 6. Atualizar registros existentes que têm subscription ativa
--    mas podem estar faltando identity/professional
-- =====================================================

-- Nota: onboarding_completed só será marcado TRUE se TODOS os 3 estiverem prontos
-- Isso garante que usuários novos passem por todo o fluxo correto

SELECT 'Migration V2 aplicada com sucesso' as result;
