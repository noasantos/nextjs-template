BEGIN;
-- 1) Remove duplicate permissive SELECT policy on google_sync_logs.
DO $$
BEGIN
  IF to_regclass('public.google_sync_logs') IS NOT NULL THEN
    DROP POLICY IF EXISTS "Psychologists can view own sync logs" ON public.google_sync_logs;
  END IF;
END;
$$;
-- 2) Restrict service-role policies to service_role (instead of PUBLIC)
-- so they no longer overlap with authenticated/anon permissive policies.

DO $$
BEGIN
  IF to_regclass('public.reference_values') IS NOT NULL THEN
    DROP POLICY IF EXISTS reference_values_service_role_all ON public.reference_values;
    CREATE POLICY reference_values_service_role_all
    ON public.reference_values
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END;
$$;
DO $$
BEGIN
  IF to_regclass('public.roles') IS NOT NULL THEN
    DROP POLICY IF EXISTS roles_service_role_all ON public.roles;
    CREATE POLICY roles_service_role_all
    ON public.roles
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END;
$$;
DO $$
BEGIN
  IF to_regclass('public.session_types') IS NOT NULL THEN
    DROP POLICY IF EXISTS session_types_service_role_all ON public.session_types;
    CREATE POLICY session_types_service_role_all
    ON public.session_types
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END;
$$;
DO $$
BEGIN
  IF to_regclass('public.psychologist_subscriptions') IS NOT NULL THEN
    DROP POLICY IF EXISTS psychologist_subscriptions_service_role_all ON public.psychologist_subscriptions;
    CREATE POLICY psychologist_subscriptions_service_role_all
    ON public.psychologist_subscriptions
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END;
$$;
COMMIT;
