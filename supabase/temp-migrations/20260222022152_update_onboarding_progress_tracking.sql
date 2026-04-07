-- migration-created-via: pnpm supabase:migration:new
-- Migration: update_onboarding_progress_tracking
-- Description: Update psychologist_onboarding_state to support 4-phase onboarding with 25% increments

-- ============================================
-- 1. ENSURE ALL REQUIRED COLUMNS EXIST
-- ============================================

-- Add phase completion tracking columns if they don't exist
DO $$
BEGIN
  -- Phase 1: Compliance & Payment
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'payment_step_completed') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN payment_step_completed BOOLEAN DEFAULT FALSE;
  END IF;

  -- Phase 1: Identity
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'identity_step_completed') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN identity_step_completed BOOLEAN DEFAULT FALSE;
  END IF;

  -- Phase 1: Professional
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'professional_step_completed') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN professional_step_completed BOOLEAN DEFAULT FALSE;
  END IF;

  -- Phase 2: Readiness (Core Setup)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'readiness_step_completed') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN readiness_step_completed BOOLEAN DEFAULT FALSE;
  END IF;

  -- Phase 3: Operational
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'operational_step_completed') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN operational_step_completed BOOLEAN DEFAULT FALSE;
  END IF;

  -- Phase 4: Profile
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'profile_step_completed') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN profile_step_completed BOOLEAN DEFAULT FALSE;
  END IF;

  -- Completion tracking
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'onboarding_completed_at') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN onboarding_completed_at TIMESTAMPTZ;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'completion_percentage') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN completion_percentage INTEGER DEFAULT 0;
  END IF;

  -- Draft data for auto-save
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'psychologist_onboarding_state' 
    AND column_name = 'draft_data') THEN
    ALTER TABLE public.psychologist_onboarding_state 
    ADD COLUMN draft_data JSONB DEFAULT '{}'::jsonb;
  END IF;
END $$;
-- ============================================
-- 2. CREATE FUNCTION TO CALCULATE PROGRESS
-- ============================================

CREATE OR REPLACE FUNCTION public.calculate_onboarding_progress(p_psychologist_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_progress INTEGER := 0;
  v_state RECORD;
BEGIN
  SELECT * INTO v_state
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = p_psychologist_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- Phase 1: Compliance & Payment (25%)
  IF v_state.identity_step_completed 
     AND v_state.professional_step_completed 
     AND v_state.payment_step_completed THEN
    v_progress := v_progress + 25;
  END IF;

  -- Phase 2: Core Setup (25%)
  IF v_state.readiness_step_completed THEN
    v_progress := v_progress + 25;
  END IF;

  -- Phase 3: Operational (25%)
  IF v_state.operational_step_completed THEN
    v_progress := v_progress + 25;
  END IF;

  -- Phase 4: Profile (25%)
  IF v_state.profile_step_completed THEN
    v_progress := v_progress + 25;
  END IF;

  RETURN v_progress;
END;
$$;
COMMENT ON FUNCTION public.calculate_onboarding_progress(UUID) IS 
'Calculates onboarding progress in 25% increments (4 phases)';
-- ============================================
-- 3. CREATE FUNCTION TO GET CURRENT PHASE
-- ============================================

CREATE OR REPLACE FUNCTION public.get_current_onboarding_phase(p_psychologist_id UUID)
RETURNS INTEGER
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
    RETURN 1;
  END IF;

  IF NOT (v_state.identity_step_completed 
          AND v_state.professional_step_completed 
          AND v_state.payment_step_completed) THEN
    RETURN 1;
  END IF;

  IF NOT v_state.readiness_step_completed THEN
    RETURN 2;
  END IF;

  IF NOT v_state.operational_step_completed THEN
    RETURN 3;
  END IF;

  IF NOT v_state.profile_step_completed THEN
    RETURN 4;
  END IF;

  RETURN 4;
END;
$$;
COMMENT ON FUNCTION public.get_current_onboarding_phase(UUID) IS 
'Returns the current onboarding phase (1-4) based on completion status';
-- ============================================
-- 4. CREATE TRIGGER TO AUTO-UPDATE PROGRESS
-- ============================================

CREATE OR REPLACE FUNCTION public.trigger_update_onboarding_progress()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.completion_percentage := public.calculate_onboarding_progress(NEW.psychologist_id);
  
  IF NEW.completion_percentage = 100 AND NEW.onboarding_completed_at IS NULL THEN
    NEW.onboarding_completed_at := NOW();
  END IF;

  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_update_onboarding_progress 
ON public.psychologist_onboarding_state;
CREATE TRIGGER trg_update_onboarding_progress
  BEFORE INSERT OR UPDATE ON public.psychologist_onboarding_state
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_update_onboarding_progress();
COMMENT ON TRIGGER trg_update_onboarding_progress ON public.psychologist_onboarding_state IS 
'Automatically updates completion percentage whenever onboarding state changes';
-- ============================================
-- 5. MIGRATE EXISTING DATA
-- ============================================

DO $$
DECLARE
  v_record RECORD;
BEGIN
  FOR v_record IN 
    SELECT psychologist_id 
    FROM public.psychologist_onboarding_state 
    WHERE completion_percentage = 0 OR completion_percentage IS NULL
  LOOP
    PERFORM public.calculate_onboarding_progress(v_record.psychologist_id);
  END LOOP;
END $$;
