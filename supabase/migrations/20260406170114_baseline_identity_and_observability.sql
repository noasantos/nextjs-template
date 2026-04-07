-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:01:14Z

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

COMMENT ON SCHEMA public IS 'standard public schema';

CREATE EXTENSION IF NOT EXISTS pg_graphql WITH SCHEMA graphql;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

SET default_tablespace = '';
SET default_table_access_method = heap;

CREATE TABLE public.app_roles (
  role text NOT NULL,
  label text NOT NULL,
  is_self_sign_up_allowed boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.app_roles ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.profiles (
  user_id uuid NOT NULL,
  full_name text,
  avatar_url text,
  subscription jsonb NOT NULL DEFAULT '{}'::jsonb,
  access_version bigint NOT NULL DEFAULT 1,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profiles_access_version_positive CHECK ((access_version >= 1))
  -- Optional: permissions jsonb NOT NULL DEFAULT '[]'::jsonb
);

-- Optional: ALTER TABLE public.profiles ADD COLUMN permissions jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.profiles.user_id IS 'FK to auth.users.id. Email/phone: only from auth.users.';
COMMENT ON COLUMN public.profiles.subscription IS 'Full billing/entitlement snapshot (DB + webhooks). JWT: only subscription_claims_for_jwt() whitelist. Keys are app-defined; Stripe uses distinct prefixes (cus_/acct_/sub_/pi_/…). Accounts v2 (Connect): one acct_ can hold merchant+customer configs; greenfield often uses stripe_account_id (acct_) + stripe_subscription_id (sub_) for platform SaaS; patient payers may use cus_ or v2 customer-only Account—see docs/guides/template-baseline-schema.md (Stripe: API version, Accounts v2). Pin Stripe apiVersion in server SDK. Never copy Stripe ids into JWT.';
COMMENT ON COLUMN public.profiles.access_version IS 'Increment when roles or subscription change; mirrored in JWT app_metadata.access_version. Compare JWT vs DB when reconciling after mutations or when JWT may be stale.';

CREATE TABLE public.user_roles (
  user_id uuid NOT NULL,
  role text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE ONLY public.app_roles ADD CONSTRAINT app_roles_pkey PRIMARY KEY (role);

ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.user_roles ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role);

CREATE INDEX idx_user_roles_user_id ON public.user_roles USING btree (user_id);

ALTER TABLE ONLY public.profiles
  ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE;

ALTER TABLE ONLY public.user_roles
  ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE;

ALTER TABLE ONLY public.user_roles
  ADD CONSTRAINT user_roles_role_fkey FOREIGN KEY (role) REFERENCES public.app_roles (role) ON DELETE CASCADE;

-- -----------------------------------------------------------------------------
-- Optional: fine-grained permissions (uncomment and wire in get_user_access_payload_core)
-- -----------------------------------------------------------------------------
-- CREATE TABLE public.user_permissions (
--   user_id uuid NOT NULL,
--   permission text NOT NULL,
--   created_at timestamp with time zone NOT NULL DEFAULT now(),
--   CONSTRAINT user_permissions_pkey PRIMARY KEY (user_id, permission),
--   CONSTRAINT user_permissions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE CASCADE
-- );
-- CREATE INDEX idx_user_permissions_user_id ON public.user_permissions USING btree (user_id);
-- ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;
-- (Add RLS policies + grants to match your threat model; hook uses SECURITY DEFINER RPCs.)

CREATE OR REPLACE FUNCTION public.auth_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT
    coalesce((auth.jwt () -> 'app_metadata' -> 'roles')::jsonb, '[]'::jsonb) @> '"admin"'::jsonb
    OR coalesce((auth.jwt () -> 'app_metadata' ->> 'role') = 'admin', false)
    OR coalesce((auth.jwt () -> 'user_metadata' -> 'roles')::jsonb, '[]'::jsonb) @> '"admin"'::jsonb
    OR coalesce((auth.jwt () -> 'user_metadata' ->> 'role') = 'admin', false)
    OR EXISTS (
      SELECT 1
      FROM public.user_roles ur
      WHERE ur.user_id = auth.uid ()
        AND ur.role = 'admin'
    );
$function$;

COMMENT ON FUNCTION public.auth_is_admin() IS 'True when JWT or user_roles grants admin (matches app claim resolution).';

CREATE OR REPLACE FUNCTION public.get_user_access_payload_core(target_user_id uuid)
RETURNS TABLE(user_id uuid, roles jsonb, permissions jsonb, access_version bigint, subscription jsonb)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT
    target_user_id,
    COALESCE(
      (
        SELECT jsonb_agg(ur.role ORDER BY ur.role)
        FROM public.user_roles ur
        WHERE ur.user_id = target_user_id
      ),
      '[]'::jsonb
    ),
    -- permissions: empty array by default. When you add user_permissions or
    -- profiles.permissions, replace with e.g.:
    -- COALESCE((SELECT jsonb_agg(up.permission ORDER BY up.permission)
    --           FROM public.user_permissions up WHERE up.user_id = target_user_id), '[]'::jsonb)
    -- or: COALESCE((SELECT p.permissions FROM public.profiles p WHERE p.user_id = target_user_id), '[]'::jsonb)
    '[]'::jsonb,
    COALESCE(
      (
        SELECT p.access_version
        FROM public.profiles p
        WHERE p.user_id = target_user_id
      ),
      1::bigint
    ),
    -- subscription: full jsonb from profiles; copied to JWT app_metadata.subscription by hook
    COALESCE(
      (
        SELECT p.subscription
        FROM public.profiles p
        WHERE p.user_id = target_user_id
      ),
      '{}'::jsonb
    );
$function$;

COMMENT ON FUNCTION public.get_user_access_payload_core(uuid) IS 'JWT source: roles, permissions (optional), access_version, subscription (profiles.subscription). custom_access_token_hook reads this for every token.';

CREATE OR REPLACE FUNCTION public.get_user_access_payload(target_user_id uuid)
RETURNS TABLE(user_id uuid, roles jsonb, permissions jsonb, access_version bigint, subscription jsonb)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT c.user_id, c.roles, c.permissions, c.access_version, c.subscription
  FROM public.get_user_access_payload_core(target_user_id) c
  WHERE target_user_id = auth.uid() OR public.auth_is_admin();
$function$;

CREATE OR REPLACE FUNCTION public.get_my_access_payload()
RETURNS TABLE(user_id uuid, roles jsonb, permissions jsonb, access_version bigint, subscription jsonb)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT *
  FROM public.get_user_access_payload(auth.uid());
$function$;

CREATE OR REPLACE FUNCTION public.subscription_claims_for_jwt(src jsonb)
RETURNS jsonb
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path TO ''
AS $function$
  SELECT COALESCE(
    jsonb_strip_nulls(
      jsonb_build_object(
        'status', src->'status',
        'plan_id', src->'plan_id',
        'plan_tier', src->'plan_tier',
        'current_period_end', src->'current_period_end',
        'provider', src->'provider'
      )
    ),
    '{}'::jsonb
  );
$function$;

COMMENT ON FUNCTION public.subscription_claims_for_jwt(jsonb) IS 'Projects profiles.subscription into client-visible JWT fields. Excludes Stripe object ids (cus_/acct_/sub_/pi_/…), payment data, and secrets—extend jsonb_build_object only with non-sensitive flags. Full row remains in DB; get_my_access_payload returns unfiltered subscription.';

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  claims jsonb;
  meta jsonb;
  acc_roles jsonb;
  acc_perms jsonb;
  acc_ver bigint;
  acc_sub jsonb;
BEGIN
  IF event->>'user_id' IS NULL OR btrim(event->>'user_id') = '' THEN
    RETURN jsonb_build_object(
      'error',
      jsonb_build_object(
        'http_code', 400,
        'message', 'custom_access_token_hook: missing user_id'
      )
    );
  END IF;

  claims := COALESCE(event->'claims', '{}'::jsonb);

  SELECT c.roles, c.permissions, c.access_version, c.subscription
  INTO acc_roles, acc_perms, acc_ver, acc_sub
  FROM public.get_user_access_payload_core((event->>'user_id')::uuid) c;

  meta := COALESCE(claims->'app_metadata', '{}'::jsonb);

  -- Stable JWT app_metadata: roles, access_version, subscription (whitelisted via subscription_claims_for_jwt)
  meta := meta || jsonb_build_object(
    'roles', acc_roles,
    'access_version', acc_ver,
    'subscription', public.subscription_claims_for_jwt(COALESCE(acc_sub, '{}'::jsonb))
  );

  -- Optional: include permissions in JWT app_metadata only when you materialize
  -- them in get_user_access_payload_core (user_permissions table or profiles.permissions).
  -- If you omit permissions entirely from tokens, delete the next line and the
  -- acc_perms variable; if you want claims only when non-empty, use:
  -- IF acc_perms IS NOT NULL AND acc_perms <> '[]'::jsonb THEN
  --   meta := meta || jsonb_build_object('permissions', acc_perms);
  -- END IF;
  meta := meta || jsonb_build_object('permissions', acc_perms);

  claims := jsonb_set(claims, '{app_metadata}', meta, true);

  RETURN jsonb_build_object('claims', claims);
END;
$function$;

COMMENT ON FUNCTION public.custom_access_token_hook(jsonb) IS 'Auth hook: read-only merge into claims.app_metadata (roles, access_version, subscription_claims_for_jwt snapshot, permissions). Register: config.toml [auth.hook.custom_access_token] uri = pg-functions://postgres/public/custom_access_token_hook';

CREATE OR REPLACE FUNCTION public.sync_user_roles(p_user_id uuid, p_roles text[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  DELETE FROM public.user_roles
  WHERE user_id = p_user_id;

  INSERT INTO public.user_roles (user_id, role)
  SELECT DISTINCT
    p_user_id,
    r
  FROM unnest(coalesce(p_roles, array[]::text[])) AS r
  WHERE btrim(r) <> '';

  UPDATE public.profiles
  SET
    access_version = access_version + 1,
    updated_at = now()
  WHERE user_id = p_user_id;
END;
$function$;

COMMENT ON FUNCTION public.sync_user_roles(uuid, text[]) IS 'Replace user_roles for a user; bumps profiles.access_version so JWT picks up new roles (with subscription unchanged unless you also call sync_profile_subscription).';

CREATE OR REPLACE FUNCTION public.sync_profile_subscription(p_user_id uuid, p_subscription jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.profiles
  SET
    subscription = COALESCE(profiles.subscription, '{}'::jsonb) || COALESCE(p_subscription, '{}'::jsonb),
    access_version = access_version + 1,
    updated_at = now()
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'sync_profile_subscription: missing profiles row for user %', p_user_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;
END;
$function$;

COMMENT ON FUNCTION public.sync_profile_subscription(uuid, jsonb) IS 'Merge p_subscription into profiles.subscription (full jsonb ||), bump access_version. Webhooks may write Stripe ids here; JWT still exposes only subscription_claims_for_jwt. Next refresh picks up new claims.';

CREATE TABLE public.observability_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_family text NOT NULL,
  event_name text NOT NULL,
  "timestamp" timestamp with time zone NOT NULL DEFAULT now(),
  trace_id text NOT NULL,
  correlation_id text NOT NULL,
  correlation_provenance text NOT NULL,
  service text NOT NULL,
  component text NOT NULL,
  runtime text NOT NULL,
  environment text NOT NULL,
  actor_type text NOT NULL,
  actor_id_hash text,
  role text,
  operation text NOT NULL,
  operation_type text NOT NULL,
  outcome text NOT NULL,
  error_category text,
  error_code text,
  error_message text,
  duration_ms integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  request_path text,
  http_status integer,
  user_agent text,
  ip_hash text,
  severity text NOT NULL
);

ALTER TABLE public.observability_events ENABLE ROW LEVEL SECURITY;

CREATE INDEX idx_observability_events_actor_id_hash ON public.observability_events USING btree (actor_id_hash);
CREATE INDEX idx_observability_events_correlation_id ON public.observability_events USING btree (correlation_id);
CREATE INDEX idx_observability_events_family_name_timestamp ON public.observability_events USING btree (event_family, event_name, "timestamp" DESC);
CREATE INDEX idx_observability_events_outcome_timestamp ON public.observability_events USING btree (outcome, "timestamp" DESC);
CREATE INDEX idx_observability_events_service_component_timestamp ON public.observability_events USING btree (service, component, "timestamp" DESC);
CREATE INDEX idx_observability_events_timestamp_desc ON public.observability_events USING btree ("timestamp" DESC);
CREATE INDEX idx_observability_events_trace_id ON public.observability_events USING btree (trace_id);

ALTER TABLE ONLY public.observability_events ADD CONSTRAINT observability_events_pkey PRIMARY KEY (id);

ALTER TABLE public.observability_events
  ADD CONSTRAINT observability_events_correlation_provenance_check
  CHECK ((correlation_provenance = ANY (ARRAY['generated'::text, 'inherited'::text])));

ALTER TABLE public.observability_events
  ADD CONSTRAINT observability_events_outcome_check
  CHECK ((outcome = ANY (ARRAY['success'::text, 'failure'::text, 'unknown'::text])));

ALTER TABLE public.observability_events
  ADD CONSTRAINT observability_events_runtime_check
  CHECK ((runtime = ANY (ARRAY['node'::text, 'edge'::text, 'browser'::text])));

ALTER TABLE public.observability_events
  ADD CONSTRAINT observability_events_severity_check
  CHECK ((severity = ANY (ARRAY['debug'::text, 'info'::text, 'warn'::text, 'error'::text])));

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.observability_events TO service_role;
REVOKE ALL PRIVILEGES ON TABLE public.observability_events FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.observability_events FROM authenticated;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_insert_own ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK ((user_id = auth.uid()));

CREATE POLICY profiles_select_own_or_admin ON public.profiles
  FOR SELECT TO authenticated
  USING (((user_id = auth.uid()) OR public.auth_is_admin()));

CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE TO authenticated
  USING ((user_id = auth.uid()))
  WITH CHECK ((user_id = auth.uid()));

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_roles_delete_admin ON public.user_roles
  FOR DELETE TO authenticated
  USING (public.auth_is_admin());

CREATE POLICY user_roles_insert_admin ON public.user_roles
  FOR INSERT TO authenticated
  WITH CHECK (public.auth_is_admin());

CREATE POLICY user_roles_select_own_or_admin ON public.user_roles
  FOR SELECT TO authenticated
  USING (((user_id = auth.uid()) OR public.auth_is_admin()));

CREATE POLICY user_roles_update_admin ON public.user_roles
  FOR UPDATE TO authenticated
  USING (public.auth_is_admin())
  WITH CHECK (public.auth_is_admin());

CREATE POLICY app_roles_delete_admin ON public.app_roles
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (public.auth_is_admin());

CREATE POLICY app_roles_insert_admin ON public.app_roles
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (public.auth_is_admin());

CREATE POLICY app_roles_select_authenticated ON public.app_roles
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

CREATE POLICY app_roles_update_admin ON public.app_roles
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (public.auth_is_admin())
  WITH CHECK (public.auth_is_admin());

ALTER PUBLICATION supabase_realtime OWNER TO postgres;

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;

GRANT ALL ON FUNCTION public.auth_is_admin() TO anon;
GRANT ALL ON FUNCTION public.auth_is_admin() TO authenticated;
GRANT ALL ON FUNCTION public.auth_is_admin() TO service_role;

GRANT EXECUTE ON FUNCTION public.get_user_access_payload_core(uuid) TO supabase_auth_admin;
REVOKE ALL ON FUNCTION public.get_user_access_payload_core(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_user_access_payload_core(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.get_user_access_payload_core(uuid) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.subscription_claims_for_jwt(jsonb) TO supabase_auth_admin;
REVOKE ALL ON FUNCTION public.subscription_claims_for_jwt(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.subscription_claims_for_jwt(jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.subscription_claims_for_jwt(jsonb) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;
REVOKE ALL ON FUNCTION public.custom_access_token_hook(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.custom_access_token_hook(jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.custom_access_token_hook(jsonb) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.sync_user_roles(uuid, text[]) TO service_role;
REVOKE ALL ON FUNCTION public.sync_user_roles(uuid, text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_user_roles(uuid, text[]) FROM anon;
REVOKE ALL ON FUNCTION public.sync_user_roles(uuid, text[]) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.sync_profile_subscription(uuid, jsonb) TO service_role;
REVOKE ALL ON FUNCTION public.sync_profile_subscription(uuid, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_profile_subscription(uuid, jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.sync_profile_subscription(uuid, jsonb) FROM authenticated;

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;

GRANT ALL ON TABLE public.user_roles TO anon;
GRANT ALL ON TABLE public.user_roles TO authenticated;
GRANT ALL ON TABLE public.user_roles TO service_role;

GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.app_roles TO anon;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.app_roles TO authenticated;
GRANT DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.app_roles TO service_role;

GRANT ALL ON FUNCTION public.get_user_access_payload(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_user_access_payload(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_user_access_payload(uuid) TO service_role;

GRANT ALL ON FUNCTION public.get_my_access_payload() TO anon;
GRANT ALL ON FUNCTION public.get_my_access_payload() TO authenticated;
GRANT ALL ON FUNCTION public.get_my_access_payload() TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;

COMMENT ON TABLE public.profiles IS 'App profile per auth.users id; subscription jsonb → JWT app_metadata.subscription via hook; no email/phone (use auth.users).';
COMMENT ON TABLE public.user_roles IS 'Application roles per user; reflected in JWT app_metadata.roles.';
