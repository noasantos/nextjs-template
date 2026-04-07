-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T13:03:31Z
-- Fix: Update remaining functions to use configuration_step_completed instead of readiness_step_completed

-- =====================================================
-- 1. Fix complete_onboarding_step function (text param)
-- =====================================================

CREATE OR REPLACE FUNCTION public.complete_onboarding_step(
  p_step text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_psychologist_id uuid;
BEGIN
  -- Get psychologist_id for current user
  SELECT psychologist_id INTO v_psychologist_id
  FROM user_psychologists
  WHERE user_id = auth.uid();
  
  IF v_psychologist_id IS NULL THEN
    RAISE EXCEPTION 'Psychologist not found for current user';
  END IF;
  
  -- Mark specific step as complete
  CASE p_step
    WHEN 'identity' THEN
      UPDATE psychologist_onboarding_state 
      SET identity_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    WHEN 'professional' THEN
      UPDATE psychologist_onboarding_state 
      SET professional_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    WHEN 'payment' THEN
      UPDATE psychologist_onboarding_state 
      SET payment_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    WHEN 'configuration' THEN
      UPDATE psychologist_onboarding_state 
      SET configuration_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    WHEN 'profile' THEN
      UPDATE psychologist_onboarding_state 
      SET profile_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    ELSE
      RAISE EXCEPTION 'Unknown onboarding step: %', p_step;
  END CASE;
  
  RETURN true;
END;
$$;
COMMENT ON FUNCTION public.complete_onboarding_step(text) IS 
'Marks a specific onboarding step as complete.
Steps: identity → professional → payment → configuration → profile';
-- =====================================================
-- 1b. Fix complete_onboarding_step function (uuid, text params)
-- =====================================================

DROP FUNCTION IF EXISTS public.complete_onboarding_step(uuid, text);
CREATE OR REPLACE FUNCTION public.complete_onboarding_step(
  p_psychologist_id UUID,
  p_step TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_all_complete BOOLEAN;
BEGIN
  -- Update specific step
  UPDATE public.psychologist_onboarding_state
  SET 
    payment_step_completed = CASE WHEN p_step = 'payment' THEN TRUE ELSE payment_step_completed END,
    identity_step_completed = CASE WHEN p_step = 'identity' THEN TRUE ELSE identity_step_completed END,
    professional_step_completed = CASE WHEN p_step = 'professional' THEN TRUE ELSE professional_step_completed END,
    configuration_step_completed = CASE WHEN p_step = 'configuration' THEN TRUE ELSE configuration_step_completed END,
    profile_step_completed = CASE WHEN p_step = 'profile' THEN TRUE ELSE profile_step_completed END,
    updated_at = NOW()
  WHERE psychologist_id = p_psychologist_id;
  
  -- Recalculate progress
  PERFORM public.calculate_onboarding_progress(p_psychologist_id);
  
  -- Check if all steps are complete
  SELECT (
    payment_step_completed 
    AND identity_step_completed 
    AND professional_step_completed 
    AND configuration_step_completed 
    AND profile_step_completed
  ) INTO v_all_complete
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = p_psychologist_id;
  
  -- If complete, mark timestamp
  IF v_all_complete THEN
    UPDATE public.psychologist_onboarding_state
    SET onboarding_completed_at = COALESCE(onboarding_completed_at, NOW()),
        updated_at = NOW()
    WHERE psychologist_id = p_psychologist_id;
    
    -- Also update flag in user_psychologists for compatibility
    UPDATE public.user_psychologists
    SET onboarding_completed = TRUE,
        updated_at = NOW()
    WHERE id = p_psychologist_id;
  END IF;
  
  RETURN TRUE;
END;
$$;
COMMENT ON FUNCTION public.complete_onboarding_step(UUID, TEXT) IS 
'Marks a specific onboarding step as complete for a given psychologist.
Steps: identity → professional → payment → configuration → profile';
-- =====================================================
-- 2. Fix is_onboarding_fully_complete function
-- =====================================================

CREATE OR REPLACE FUNCTION public.is_onboarding_fully_complete(p_psychologist_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_state RECORD;
BEGIN
  SELECT * INTO v_state
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = p_psychologist_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- All 5 steps must be complete
  RETURN (
    v_state.identity_step_completed 
    AND v_state.professional_step_completed 
    AND v_state.payment_step_completed
    AND v_state.configuration_step_completed
    AND v_state.profile_step_completed
  );
END;
$$;
COMMENT ON FUNCTION public.is_onboarding_fully_complete(UUID) IS 
'Returns TRUE when all 5 onboarding steps are complete (identity + professional + payment + configuration + profile).';
-- =====================================================
-- 3. Fix get_current_onboarding_phase function if exists
-- =====================================================

DROP FUNCTION IF EXISTS public.get_current_onboarding_phase(UUID);
CREATE OR REPLACE FUNCTION public.get_current_onboarding_phase(p_user_id UUID DEFAULT NULL)
RETURNS TABLE (
  phase TEXT,
  step_number INTEGER,
  step_name TEXT,
  is_complete BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_state RECORD;
BEGIN
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  SELECT * INTO v_state
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = v_user_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'not_started'::TEXT, 0::INTEGER, ''::TEXT, FALSE::BOOLEAN;
    RETURN;
  END IF;
  
  IF v_state.profile_step_completed THEN
    RETURN QUERY SELECT 'complete'::TEXT, 5::INTEGER, 'profile'::TEXT, TRUE::BOOLEAN;
  ELSIF v_state.configuration_step_completed THEN
    RETURN QUERY SELECT 'phase2'::TEXT, 4::INTEGER, 'configuration'::TEXT, FALSE::BOOLEAN;
  ELSIF v_state.payment_step_completed THEN
    RETURN QUERY SELECT 'phase1'::TEXT, 3::INTEGER, 'payment'::TEXT, FALSE::BOOLEAN;
  ELSIF v_state.professional_step_completed THEN
    RETURN QUERY SELECT 'phase1'::TEXT, 2::INTEGER, 'professional'::TEXT, FALSE::BOOLEAN;
  ELSIF v_state.identity_step_completed THEN
    RETURN QUERY SELECT 'phase1'::TEXT, 1::INTEGER, 'identity'::TEXT, FALSE::BOOLEAN;
  ELSE
    RETURN QUERY SELECT 'not_started'::TEXT, 0::INTEGER, ''::TEXT, FALSE::BOOLEAN;
  END IF;
END;
$$;
COMMENT ON FUNCTION public.get_current_onboarding_phase(UUID) IS 
'Returns the current onboarding phase and step for a user.';
-- Reset schema cache
NOTIFY pgrst, 'reload schema';
