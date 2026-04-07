-- Migration: fix_onboarding_status_rpc
-- Description: Update get_onboarding_status_by_user to use user_psychologists table after identity refactor
-- Fixes: Login redirect loop where psychologists with active subscriptions were sent to onboarding

-- Drop old function that references non-existent psychologists table
DROP FUNCTION IF EXISTS public.get_onboarding_status_by_user(uuid) CASCADE;
-- Recreate with correct table reference
CREATE OR REPLACE FUNCTION public.get_onboarding_status_by_user(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p_role public.app_role;
  p_status boolean;
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
  
  -- Get onboarding status from user_psychologists (NOT psychologists)
  SELECT onboarding_completed INTO p_status
  FROM public.user_psychologists
  WHERE id = p_user_id;
  
  -- Return status, defaulting to false if NULL
  RETURN coalesce(p_status, false);
END;
$$;
COMMENT ON FUNCTION public.get_onboarding_status_by_user(uuid) IS 
'Returns true if user has completed onboarding (psychologists only) or is not a psychologist. Uses user_psychologists table after identity refactor.';
