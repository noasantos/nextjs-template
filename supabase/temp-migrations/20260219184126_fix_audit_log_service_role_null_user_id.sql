-- Migration: fix_audit_log_service_role_null_user_id
-- Problem: process_audit_log() calls auth.uid() which returns NULL when the operation
--          is performed by the service role (e.g. provision_user_role RPC called from
--          the provision-user-role edge function). This causes INSERT into audit_logs to
--          fail with "null value in column user_id violates not-null constraint", rolling
--          back the entire transaction or surfacing a raw DB error to the client.
--
-- Fix:
--   1. Drop NOT NULL from audit_logs.user_id so service-role operations can be logged.
--   2. Update process_audit_log() to detect service-role context (auth.uid() IS NULL),
--      set user_type = 'service_role', and attempt to recover user_id from the row itself.

-- 1. Allow NULL user_id for service-role-initiated audit entries
ALTER TABLE public.audit_logs ALTER COLUMN user_id DROP NOT NULL;
-- 2. Update trigger function to handle service-role (no auth context)
CREATE OR REPLACE FUNCTION public.process_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id        UUID;
  v_user_type      TEXT;
  v_record_id      TEXT;
  v_changed_fields JSONB;
  v_old_data       JSONB;
  v_new_data       JSONB;
  v_correlation_id UUID;
BEGIN
  -- Attempt to get the authenticated user (NULL when called from service role)
  v_user_id := auth.uid();

  IF v_user_id IS NOT NULL THEN
    -- Normal authenticated context: look up the user's role
    SELECT role::text INTO v_user_type
    FROM public.user_roles
    WHERE user_id = v_user_id
    LIMIT 1;

    IF v_user_type IS NULL THEN
      v_user_type := 'unknown';
    END IF;
  ELSE
    -- Service-role context: no JWT, mark accordingly
    v_user_type := 'service_role';

    -- Best-effort: recover user_id from the row being mutated (e.g. user_roles.user_id)
    BEGIN
      IF TG_OP = 'DELETE' THEN
        v_user_id := OLD.user_id;
      ELSE
        v_user_id := NEW.user_id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_user_id := NULL; -- Column does not exist on this table, keep NULL
    END;
  END IF;

  -- Derive record PK
  IF TG_OP = 'DELETE' THEN
    v_record_id := OLD.id::TEXT;
  ELSE
    v_record_id := NEW.id::TEXT;
  END IF;

  -- Build change payload
  CASE TG_OP
    WHEN 'INSERT' THEN
      v_new_data       := to_jsonb(NEW);
      v_changed_fields := jsonb_build_object('new', v_new_data, 'old', NULL);

    WHEN 'UPDATE' THEN
      v_old_data := to_jsonb(OLD);
      v_new_data := to_jsonb(NEW);
      SELECT jsonb_object_agg(key, value)
      INTO   v_changed_fields
      FROM   jsonb_each(v_new_data)
      WHERE  v_old_data->key IS DISTINCT FROM value;
      v_changed_fields := jsonb_build_object(
        'old',     v_old_data,
        'new',     v_new_data,
        'changed', v_changed_fields
      );

    WHEN 'DELETE' THEN
      v_old_data       := to_jsonb(OLD);
      v_changed_fields := jsonb_build_object('old', v_old_data, 'new', NULL);
  END CASE;

  v_correlation_id := gen_random_uuid();

  INSERT INTO public.audit_logs (
    user_id,
    user_type,
    table_name,
    record_id,
    action,
    changed_fields,
    correlation_id,
    created_at
  ) VALUES (
    v_user_id,       -- NULL is allowed; service_role rows will have user_type = 'service_role'
    v_user_type,
    TG_TABLE_NAME,
    v_record_id,
    TG_OP,
    v_changed_fields,
    v_correlation_id,
    NOW()
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;
COMMENT ON FUNCTION public.process_audit_log() IS
  'Generic audit trigger. Handles both authenticated users (auth.uid()) and service-role '
  'operations (user_id NULL, user_type = ''service_role'').';
