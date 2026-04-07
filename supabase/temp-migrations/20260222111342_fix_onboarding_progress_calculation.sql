-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T11:13:42Z

-- =====================================================
-- FIX: Correct progress calculation for 5 individual steps
-- =====================================================
-- BEFORE: Calculated by phases (4 phases x 25% each)
-- AFTER: Calculates by individual steps (5 steps x 20% each)
--
-- Steps:
--   1. Payment (20%)
--   2. Identity (20%)
--   3. Professional (20%)
--   4. Readiness (20%)
--   5. Profile (20%)

-- Temporarily disable trigger to avoid recursion
ALTER TABLE psychologist_onboarding_state DISABLE TRIGGER trg_update_onboarding_progress;
-- Update the function
CREATE OR REPLACE FUNCTION public.calculate_onboarding_progress(p_psychologist_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_completed_steps INTEGER := 0;
  v_total_steps INTEGER := 5;
  v_progress INTEGER;
  v_state RECORD;
BEGIN
  SELECT * INTO v_state 
  FROM public.psychologist_onboarding_state 
  WHERE psychologist_id = p_psychologist_id;
  
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  
  -- Count individual completed steps (5 steps, 20% each)
  IF v_state.payment_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.identity_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.professional_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.readiness_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.profile_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  
  v_progress := (v_completed_steps * 100) / v_total_steps;
  
  -- Update table (without triggering recursion)
  UPDATE public.psychologist_onboarding_state
  SET completion_percentage = v_progress,
      current_step = CASE 
        WHEN v_state.onboarding_completed_at IS NOT NULL THEN v_total_steps + 1
        WHEN v_state.profile_step_completed THEN 5
        WHEN v_state.readiness_step_completed THEN 4
        WHEN v_state.professional_step_completed THEN 3
        WHEN v_state.identity_step_completed THEN 2
        WHEN v_state.payment_step_completed THEN 1
        ELSE 1
      END
  WHERE psychologist_id = p_psychologist_id;
  
  RETURN v_progress;
END;
$function$;
-- Recalculate progress for all users (com trigger desabilitado para evitar recursão)
UPDATE psychologist_onboarding_state
SET completion_percentage = (
  (CASE WHEN payment_step_completed THEN 20 ELSE 0 END) +
  (CASE WHEN identity_step_completed THEN 20 ELSE 0 END) +
  (CASE WHEN professional_step_completed THEN 20 ELSE 0 END) +
  (CASE WHEN readiness_step_completed THEN 20 ELSE 0 END) +
  (CASE WHEN profile_step_completed THEN 20 ELSE 0 END)
),
current_step = CASE 
  WHEN onboarding_completed_at IS NOT NULL THEN 6
  WHEN profile_step_completed THEN 5
  WHEN readiness_step_completed THEN 4
  WHEN professional_step_completed THEN 3
  WHEN identity_step_completed THEN 2
  WHEN payment_step_completed THEN 1
  ELSE 1
END;
-- Re-enable trigger apenas no final
ALTER TABLE psychologist_onboarding_state ENABLE TRIGGER trg_update_onboarding_progress;
-- Show summary
SELECT 
  'Progress recalculated for all users' as status,
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE completion_percentage = 0) as at_0_percent,
  COUNT(*) FILTER (WHERE completion_percentage = 20) as at_20_percent,
  COUNT(*) FILTER (WHERE completion_percentage = 40) as at_40_percent,
  COUNT(*) FILTER (WHERE completion_percentage = 60) as at_60_percent,
  COUNT(*) FILTER (WHERE completion_percentage = 80) as at_80_percent,
  COUNT(*) FILTER (WHERE completion_percentage = 100) as at_100_percent
FROM psychologist_onboarding_state;
