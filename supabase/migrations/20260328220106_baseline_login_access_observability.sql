-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-03-28T22:01:06Z
--
-- Baseline: append-only observability_events (service_role), minimal identity (profiles),
-- template app_roles + user_roles, and custom_access_token_hook enriching JWT app_metadata
-- with roles, permissions (empty template), access_version, and subscription snapshot.

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
  email text NOT NULL,
  full_name text,
  avatar_url text,
  subscription jsonb NOT NULL DEFAULT '{}'::jsonb,
  access_version bigint NOT NULL DEFAULT 1,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profiles_access_version_positive CHECK ((access_version >= 1))
);

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
    '[]'::jsonb,
    COALESCE(
      (
        SELECT p.access_version
        FROM public.profiles p
        WHERE p.user_id = target_user_id
      ),
      1::bigint
    ),
    COALESCE(
      (
        SELECT p.subscription
        FROM public.profiles p
        WHERE p.user_id = target_user_id
      ),
      '{}'::jsonb
    );
$function$;

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
  meta := meta || jsonb_build_object(
    'roles', acc_roles,
    'permissions', acc_perms,
    'access_version', acc_ver,
    'subscription', acc_sub
  );
  claims := jsonb_set(claims, '{app_metadata}', meta, true);

  RETURN jsonb_build_object('claims', claims);
END;
$function$;

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

GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;
REVOKE ALL ON FUNCTION public.custom_access_token_hook(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.custom_access_token_hook(jsonb) FROM anon;
REVOKE ALL ON FUNCTION public.custom_access_token_hook(jsonb) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.sync_user_roles(uuid, text[]) TO service_role;
REVOKE ALL ON FUNCTION public.sync_user_roles(uuid, text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sync_user_roles(uuid, text[]) FROM anon;
REVOKE ALL ON FUNCTION public.sync_user_roles(uuid, text[]) FROM authenticated;

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

COMMENT ON TABLE public.profiles IS 'User-facing profile row keyed by auth user id; subscription JSON is mirrored into JWT app_metadata by custom_access_token_hook.';
COMMENT ON TABLE public.user_roles IS 'Application roles per user; complements JWT app_metadata.';
COMMENT ON FUNCTION public.sync_user_roles(uuid, text[]) IS 'Replaces user_roles for a user and bumps profiles.access_version when a profile row exists.';
