BEGIN;
-- 1) Ensure RLS is enabled on public tables that already have RLS policies.
ALTER TABLE IF EXISTS public.psychologist_onboarding_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.psychologist_patient_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.psychologist_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.public_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_assistants ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_psychologists ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_roles ENABLE ROW LEVEL SECURITY;
-- 2) Prevent SECURITY DEFINER view behavior by forcing security_invoker.
DO $$
BEGIN
  IF to_regclass('public.psychologist_derived_modality') IS NOT NULL THEN
    EXECUTE 'ALTER VIEW public.psychologist_derived_modality SET (security_invoker = true)';
  END IF;
END;
$$;
DO $$
BEGIN
  IF to_regclass('public.calendar_events_full') IS NOT NULL THEN
    EXECUTE 'ALTER VIEW public.calendar_events_full SET (security_invoker = true)';
  END IF;
END;
$$;
COMMIT;
