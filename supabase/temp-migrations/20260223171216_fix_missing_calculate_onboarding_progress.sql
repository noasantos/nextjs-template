-- migration-created-via: pnpm supabase:migration:new
-- Migration: fix_missing_calculate_onboarding_progress
-- Created at: 2026-02-23T17:12:16Z
-- Purpose: Recreate calculate_onboarding_progress function that was dropped but not recreated

-- =============================================================================
-- RECRIAR FUNÇÃO calculate_onboarding_progress COM search_path
-- =============================================================================
-- A função foi dropada em 20260222184642_fix_security_linter_issues.sql
-- mas não foi recriada com o SET search_path, causando erro 42883

CREATE OR REPLACE FUNCTION public.calculate_onboarding_progress(p_psychologist_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_completed_steps INTEGER := 0;
  v_state RECORD;
BEGIN
  -- Obter estado atual uma única vez
  SELECT 
    identity_step_completed,
    professional_step_completed,
    payment_step_completed,
    configuration_step_completed,
    profile_step_completed
  INTO v_state
  FROM psychologist_onboarding_state 
  WHERE psychologist_id = p_psychologist_id;
  
  -- Retornar 0 se não houver registro de onboarding
  IF v_state IS NULL THEN
    RETURN 0;
  END IF;
  
  -- Contar passos completos (5 passos, 20% cada)
  IF v_state.identity_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.professional_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.payment_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.configuration_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.profile_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  
  RETURN (v_completed_steps * 100) / 5;
END;
$$;

COMMENT ON FUNCTION public.calculate_onboarding_progress(uuid) IS 
'Calcula a porcentagem de progresso do onboarding baseado em 5 passos (20% cada). 
Inclui SET search_path para segurança (fix pós-migração 20260222184642).';

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.calculate_onboarding_progress(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_onboarding_progress(uuid) TO service_role;
