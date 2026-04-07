BEGIN;
-- reference_values: unified lookup catalog (public read of active values).
ALTER TABLE IF EXISTS public.reference_values ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN IF to_regclass('public.reference_values') IS NOT NULL THEN DROP POLICY IF EXISTS reference_values_select_authenticated ON public.reference_values; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.reference_values') IS NOT NULL THEN
  CREATE POLICY reference_values_select_authenticated
  ON public.reference_values
  FOR SELECT
  TO authenticated
  USING (is_active = true);
END IF; END $$;
DO $$ BEGIN IF to_regclass('public.reference_values') IS NOT NULL THEN DROP POLICY IF EXISTS reference_values_select_anon ON public.reference_values; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.reference_values') IS NOT NULL THEN
  CREATE POLICY reference_values_select_anon
  ON public.reference_values
  FOR SELECT
  TO anon
  USING (is_active = true);
END IF; END $$;
DO $$ BEGIN IF to_regclass('public.reference_values') IS NOT NULL THEN DROP POLICY IF EXISTS reference_values_service_role_all ON public.reference_values; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.reference_values') IS NOT NULL THEN
  CREATE POLICY reference_values_service_role_all
  ON public.reference_values
  FOR ALL
  TO PUBLIC
  USING ((SELECT auth.role()) = 'service_role'::text)
  WITH CHECK ((SELECT auth.role()) = 'service_role'::text);
END IF; END $$;
-- roles: role catalog readable by authenticated users.
ALTER TABLE IF EXISTS public.roles ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN IF to_regclass('public.roles') IS NOT NULL THEN DROP POLICY IF EXISTS roles_select_authenticated ON public.roles; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.roles') IS NOT NULL THEN
  CREATE POLICY roles_select_authenticated
  ON public.roles
  FOR SELECT
  TO authenticated
  USING (true);
END IF; END $$;
DO $$ BEGIN IF to_regclass('public.roles') IS NOT NULL THEN DROP POLICY IF EXISTS roles_service_role_all ON public.roles; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.roles') IS NOT NULL THEN
  CREATE POLICY roles_service_role_all
  ON public.roles
  FOR ALL
  TO PUBLIC
  USING ((SELECT auth.role()) = 'service_role'::text)
  WITH CHECK ((SELECT auth.role()) = 'service_role'::text);
END IF; END $$;
-- session_types: session type catalog readable by authenticated users.
ALTER TABLE IF EXISTS public.session_types ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN IF to_regclass('public.session_types') IS NOT NULL THEN DROP POLICY IF EXISTS session_types_select_authenticated ON public.session_types; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.session_types') IS NOT NULL THEN
  CREATE POLICY session_types_select_authenticated
  ON public.session_types
  FOR SELECT
  TO authenticated
  USING (true);
END IF; END $$;
DO $$ BEGIN IF to_regclass('public.session_types') IS NOT NULL THEN DROP POLICY IF EXISTS session_types_service_role_all ON public.session_types; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.session_types') IS NOT NULL THEN
  CREATE POLICY session_types_service_role_all
  ON public.session_types
  FOR ALL
  TO PUBLIC
  USING ((SELECT auth.role()) = 'service_role'::text)
  WITH CHECK ((SELECT auth.role()) = 'service_role'::text);
END IF; END $$;
-- psychologist_subscriptions: owner read + service-role write/read.
ALTER TABLE IF EXISTS public.psychologist_subscriptions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN IF to_regclass('public.psychologist_subscriptions') IS NOT NULL THEN DROP POLICY IF EXISTS psychologist_subscriptions_owner_select ON public.psychologist_subscriptions; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.psychologist_subscriptions') IS NOT NULL THEN
  CREATE POLICY psychologist_subscriptions_owner_select
  ON public.psychologist_subscriptions
  FOR SELECT
  TO authenticated
  USING (psychologist_id = (SELECT auth.uid()));
END IF; END $$;
DO $$ BEGIN IF to_regclass('public.psychologist_subscriptions') IS NOT NULL THEN DROP POLICY IF EXISTS psychologist_subscriptions_service_role_all ON public.psychologist_subscriptions; END IF; END $$;
DO $$ BEGIN IF to_regclass('public.psychologist_subscriptions') IS NOT NULL THEN
  CREATE POLICY psychologist_subscriptions_service_role_all
  ON public.psychologist_subscriptions
  FOR ALL
  TO PUBLIC
  USING ((SELECT auth.role()) = 'service_role'::text)
  WITH CHECK ((SELECT auth.role()) = 'service_role'::text);
END IF; END $$;
COMMIT;
