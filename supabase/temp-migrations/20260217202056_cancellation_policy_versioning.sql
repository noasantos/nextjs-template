-- Migration: cancellation_policy_versioning
-- Description: Implement cancellation policy versioning with triggers and enforcement functions

-------------------------------------------------------------------------------
-- 1. TRIGGER: Auto-deactivate previous policy on new insert
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.tr_close_previous_cancellation_policy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Close the previous active policy by setting effective_until to now
  UPDATE public.psychologist_session_cancellation_policy
  SET effective_until = NOW()
  WHERE psychologist_id = NEW.psychologist_id
    AND effective_until IS NULL
    AND id IS DISTINCT FROM NEW.id;
  
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.tr_close_previous_cancellation_policy() IS 'Automatically deactivates the previous cancellation policy when a new one is inserted';
-- Create the trigger
DROP TRIGGER IF EXISTS trg_close_previous_cancellation_policy ON public.psychologist_session_cancellation_policy;
CREATE TRIGGER trg_close_previous_cancellation_policy
  AFTER INSERT ON public.psychologist_session_cancellation_policy
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_close_previous_cancellation_policy();
-------------------------------------------------------------------------------
-- 2. FUNCTION: Get effective cancellation policy at a point in time
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_effective_cancellation_policy(
  p_psychologist_id UUID,
  p_reference_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE (
  policy_code TEXT,
  fee_percentage INTEGER,
  min_notice_hours INTEGER,
  effective_from TIMESTAMP WITH TIME ZONE,
  effective_until TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pscp.policy_code::TEXT,
    (rv.metadata->>'fee_percentage')::INTEGER as fee_percentage,
    (rv.metadata->>'min_notice_hours')::INTEGER as min_notice_hours,
    pscp.effective_from,
    pscp.effective_until
  FROM public.psychologist_session_cancellation_policy pscp
  JOIN public.reference_values rv 
    ON rv.value = pscp.policy_code::TEXT 
    AND rv.category = 'cancellation_policy'
  WHERE pscp.psychologist_id = p_psychologist_id
    AND p_reference_timestamp >= pscp.effective_from
    AND (pscp.effective_until IS NULL OR p_reference_timestamp < pscp.effective_until)
  ORDER BY pscp.effective_from DESC
  LIMIT 1;
END;
$$;
COMMENT ON FUNCTION public.get_effective_cancellation_policy(UUID, TIMESTAMP WITH TIME ZONE) IS 'Retrieves the cancellation policy that was active at a specific point in time';
-------------------------------------------------------------------------------
-- 3. FUNCTION: Calculate cancellation fee for a session
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.calculate_cancellation_fee(
  p_psychologist_id UUID,
  p_session_start_time TIMESTAMP WITH TIME ZONE,
  p_cancellation_time TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE (
  fee_percentage INTEGER,
  min_notice_hours INTEGER,
  hours_before_session NUMERIC,
  policy_applies BOOLEAN,
  fee_amount_cents INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_policy RECORD;
  v_hours_before NUMERIC;
  v_policy_applies BOOLEAN;
BEGIN
  -- Get the effective policy (at the time of booking, which we approximate as session creation)
  -- For now, we use the current policy. In a real scenario, we'd store the policy at booking time
  SELECT * INTO v_policy
  FROM public.get_effective_cancellation_policy(p_psychologist_id, p_cancellation_time);
  
  -- Calculate hours before session
  v_hours_before := EXTRACT(EPOCH FROM (p_session_start_time - p_cancellation_time)) / 3600;
  
  -- Determine if policy applies (if we're within the notice period)
  v_policy_applies := v_hours_before < v_policy.min_notice_hours;
  
  RETURN QUERY
  SELECT 
    v_policy.fee_percentage,
    v_policy.min_notice_hours,
    v_hours_before,
    v_policy_applies,
    CASE WHEN v_policy_applies THEN v_policy.fee_percentage ELSE 0 END as fee_amount_cents;
END;
$$;
COMMENT ON FUNCTION public.calculate_cancellation_fee(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) IS 'Calculates the cancellation fee based on the effective policy and time until session';
-------------------------------------------------------------------------------
-- 4. FUNCTION: Set psychologist cancellation policy (convenience function)
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_psychologist_cancellation_policy(
  p_psychologist_id UUID,
  p_policy_code TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_valid_policy BOOLEAN;
BEGIN
  -- Validate the policy code exists
  SELECT EXISTS(
    SELECT 1 FROM public.reference_values 
    WHERE category = 'cancellation_policy' 
    AND value = p_policy_code
    AND is_active = true
  ) INTO v_valid_policy;
  
  IF NOT v_valid_policy THEN
    RAISE EXCEPTION 'Invalid cancellation policy code: %', p_policy_code;
  END IF;
  
  -- Insert new policy (trigger will close the previous one)
  INSERT INTO public.psychologist_session_cancellation_policy (
    psychologist_id,
    policy_code,
    effective_from
  ) VALUES (
    p_psychologist_id,
    p_policy_code::public.cancellation_policy_code,
    NOW()
  );
  
  RETURN TRUE;
END;
$$;
COMMENT ON FUNCTION public.set_psychologist_cancellation_policy(UUID, TEXT) IS 'Sets a new cancellation policy for a psychologist (inserts new version)';
-------------------------------------------------------------------------------
-- 5. TABLE DESCRIPTIONS
-------------------------------------------------------------------------------

COMMENT ON TABLE public.psychologist_session_cancellation_policy IS 'Versioned cancellation policies for psychologists. Each change creates a new record with effective_from timestamp. The trigger automatically closes the previous policy.';
COMMENT ON COLUMN public.psychologist_session_cancellation_policy.policy_code IS 'Reference to the policy type (flexible, standard, strict) from reference_values';
COMMENT ON COLUMN public.psychologist_session_cancellation_policy.effective_from IS 'When this policy version became active';
COMMENT ON COLUMN public.psychologist_session_cancellation_policy.effective_until IS 'When this policy version was superseded (NULL if currently active)';
-------------------------------------------------------------------------------
-- 6. RLS POLICIES (if not already present)
-------------------------------------------------------------------------------

-- Ensure RLS is enabled
ALTER TABLE public.psychologist_session_cancellation_policy ENABLE ROW LEVEL SECURITY;
-- Psychologists can only see their own policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'psychologist_session_cancellation_policy' 
    AND policyname = 'Psychologists can view own cancellation policies'
  ) THEN
    CREATE POLICY "Psychologists can view own cancellation policies"
      ON public.psychologist_session_cancellation_policy
      FOR SELECT
      TO authenticated
      USING (psychologist_id = auth.uid());
  END IF;
END $$;
-- Psychologists can only insert their own policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'psychologist_session_cancellation_policy' 
    AND policyname = 'Psychologists can insert own cancellation policies'
  ) THEN
    CREATE POLICY "Psychologists can insert own cancellation policies"
      ON public.psychologist_session_cancellation_policy
      FOR INSERT
      TO authenticated
      WITH CHECK (psychologist_id = auth.uid());
  END IF;
END $$;
