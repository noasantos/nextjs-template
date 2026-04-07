-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T10:18:50Z

-- =====================================================
-- FIX: Separar Fase 1 (Essencial/Pré-App) da Fase 2 (Completo/In-App)
-- =====================================================
-- Fase 1 (Essencial): subscription ativa + payment + identity + professional + readiness
--   → Libera acesso ao app (onboarding_completed = TRUE)
--   → Usuário vê banner para completar Fase 2
--
-- Fase 2 (Completo): profile + todos os anteriores
--   → Banner some (fully_complete = TRUE)
--   → onboarding_completed_at preenchido

-- =====================================================
-- 0. Limpar objetos criados manualmente (se existirem)
-- =====================================================

DROP TRIGGER IF EXISTS trg_sync_onboarding_completed ON public.user_psychologists;
DROP FUNCTION IF EXISTS public.sync_onboarding_completed_with_essential();
-- =====================================================
-- 1. Atualizar função que o AuthGuard usa
-- =====================================================
-- Agora verifica Fase 1 completa (essential_complete) em vez de Fase 2

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
  
  -- Verificar se completou Fase 1 (essencial)
  -- Fase 1 = subscription ativa OU payment_step_completed
  SELECT (
    subscription_status IN ('active', 'trialing') 
    OR onboarding_completed = TRUE
  ) INTO p_essential_complete
  FROM public.user_psychologists
  WHERE id = p_user_id;
  
  -- Return status, defaulting to false if NULL
  RETURN coalesce(p_essential_complete, false);
END;
$function$;
COMMENT ON FUNCTION public.get_onboarding_status_by_user(UUID) IS 
'Verifica se o usuário completou a Fase 1 (essencial) do onboarding. 
Fase 1 = subscription ativa OU payment_step_completed.
Retorna TRUE se o usuário pode acessar o app.';
-- =====================================================
-- 2. Criar trigger para sincronizar onboarding_completed
-- =====================================================
-- Quando subscription muda para active/trialing, marca onboarding_completed = TRUE

CREATE OR REPLACE FUNCTION public.sync_onboarding_completed_with_essential()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Sincronizar onboarding_completed com essential_complete
  -- Fase 1 (essencial) completa = acesso ao app liberado
  IF NEW.subscription_status IN ('active', 'trialing') THEN
    -- Atualizar user_psychologists.onboarding_completed
    UPDATE public.user_psychologists
    SET onboarding_completed = TRUE,
        updated_at = NOW()
    WHERE id = NEW.id
      AND onboarding_completed = FALSE;
  END IF;
  
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.sync_onboarding_completed_with_essential() IS 
'Trigger function: marca onboarding_completed = TRUE quando subscription fica ativa.
Fase 1 (essencial) completa libera acesso ao app.';
-- Criar trigger para sincronizar quando subscription_status mudar
CREATE TRIGGER trg_sync_onboarding_completed
  AFTER UPDATE OF subscription_status ON public.user_psychologists
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_onboarding_completed_with_essential();
-- =====================================================
-- 3. Atualizar registros existentes
-- =====================================================
-- Usuários com assinatura ativa mas onboarding_completed = FALSE

UPDATE public.user_psychologists
SET onboarding_completed = TRUE,
    updated_at = NOW()
WHERE subscription_status IN ('active', 'trialing')
  AND onboarding_completed = FALSE;
-- =====================================================
-- 4. Garantir que psychologist_onboarding_state tenha registros
-- =====================================================
-- Criar registros para usuários existentes que não têm

INSERT INTO public.psychologist_onboarding_state (psychologist_id)
SELECT id FROM public.user_psychologists
WHERE id NOT IN (SELECT psychologist_id FROM public.psychologist_onboarding_state)
ON CONFLICT (psychologist_id) DO NOTHING;
-- Recalcular progresso para todos
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT psychologist_id FROM public.psychologist_onboarding_state
  LOOP
    PERFORM public.calculate_onboarding_progress(r.psychologist_id);
  END LOOP;
END $$;
