-- Migration: fix_audit_log_set_config_approach
-- Description: Use set_config to pass user context through session variables for LGPD-compliant audit logging
-- Context: Local development only - improves upon the NULL-allowing fix with proper user tracking
--
-- Problem: The previous fix (20260219184126) allowed NULL user_id for service-role operations.
--          This maintains LGPD traceability for user-initiated actions but weakens it for
--          service-role operations (provision_user_role called from edge functions).
--
-- Solution: Use PostgreSQL session variables (set_config/current_setting) to pass the acting
--           user ID through the service-role boundary. This keeps user_id NOT NULL while
--           correctly attributing service-role operations to the actual user being modified.

-------------------------------------------------------------------------------
-- 1. RE-ADD NOT NULL CONSTRAINT (undoing the drifted/DROP NOT NULL from previous fix)
-------------------------------------------------------------------------------

-- First ensure any existing NULLs are handled (they shouldn't exist in a fresh local DB)
-- If migrating an existing DB with NULLs, you'd need to update them first or keep NULL allowed

ALTER TABLE public.audit_logs ALTER COLUMN user_id SET NOT NULL;
COMMENT ON COLUMN public.audit_logs.user_id IS 
  'ID of the user who made the change. Always populated via auth.uid() for user actions or set_config for service-role operations.';
-------------------------------------------------------------------------------
-- 2. UPDATE provision_user_role TO SET SESSION CONTEXT
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.provision_user_role(p_user_id uuid, p_role public.app_role)
RETURNS public.app_role
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_existing_role public.app_role;
begin
  -- Set session context so audit triggers know the acting user
  -- This is critical for service-role operations where auth.uid() returns NULL
  PERFORM set_config('app.current_user_id', p_user_id::text, true); -- true = local to transaction
  
  select role into v_existing_role from public.user_roles where user_id = p_user_id;
  if v_existing_role is not null then
    return v_existing_role;
  end if;
  
  insert into public.user_roles (user_id, role) values (p_user_id, p_role);
  
  case p_role
    when 'psychologist' then
      insert into public.user_psychologists (id, subscription_status, onboarding_completed)
      values (p_user_id, 'inactive', false)
      on conflict (id) do nothing;
    when 'patient' then
      insert into public.user_patients (id) values (p_user_id) on conflict (id) do nothing;
    when 'assistant' then
      insert into public.user_assistants (id) values (p_user_id) on conflict (id) do nothing;
    when 'admin' then
      insert into public.user_admins (id) values (p_user_id) on conflict (id) do nothing;
  end case;
  
  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('user_role', p_role)
  where id = p_user_id;
  
  return p_role;
end;
$$;
COMMENT ON FUNCTION public.provision_user_role(uuid, public.app_role) IS 
  'Provisions a user role and creates the corresponding identity record. Sets app.current_user_id session variable for audit logging.';
-------------------------------------------------------------------------------
-- 3. UPDATE process_audit_log TO USE COALESCE WITH SESSION VARIABLE
-------------------------------------------------------------------------------

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
  v_session_user_id TEXT;
BEGIN
  -- Get user ID from JWT (normal auth) OR from session variable (service role)
  -- Priority: auth.uid() for user-initiated actions, app.current_user_id for service role
  v_session_user_id := NULLIF(current_setting('app.current_user_id', true), '');
  v_user_id := COALESCE(auth.uid(), v_session_user_id::uuid);
  
  -- Determine user type and validate context
  IF auth.uid() IS NOT NULL THEN
    -- Normal authenticated context: look up the user's role
    SELECT role::text INTO v_user_type
    FROM public.user_roles
    WHERE user_id = v_user_id
    LIMIT 1;

    IF v_user_type IS NULL THEN
      v_user_type := 'authenticated';
    END IF;
  ELSIF v_session_user_id IS NOT NULL THEN
    -- Service-role context with explicit user context set
    v_user_type := 'service_role';
    
    -- Verify the session user_id matches the row being modified (for user_roles table)
    -- This provides an additional safety check
    IF TG_TABLE_NAME = 'user_roles' THEN
      IF TG_OP = 'DELETE' THEN
        IF OLD.user_id IS DISTINCT FROM v_user_id THEN
          RAISE WARNING 'Audit log mismatch: session user_id % != row user_id %', v_user_id, OLD.user_id;
        END IF;
      ELSE
        IF NEW.user_id IS DISTINCT FROM v_user_id THEN
          RAISE WARNING 'Audit log mismatch: session user_id % != row user_id %', v_user_id, NEW.user_id;
        END IF;
      END IF;
    END IF;
  ELSE
    -- No auth context AND no session variable - this should not happen for sensitive operations
    RAISE EXCEPTION 'Audit log failed: no user context available (auth.uid() is NULL and app.current_user_id not set)';
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
    v_user_id,       -- Now guaranteed NOT NULL (COALESCE + exception if both sources NULL)
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
  'Generic audit trigger with LGPD-compliant user tracking. Uses COALESCE(auth.uid(), current_setting(''app.current_user_id'')) '
  'to handle both user-initiated and service-role operations. Raises exception if no user context is available.';
-------------------------------------------------------------------------------
-- 4. HELPER FUNCTION: Set audit context (for other service-role operations)
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_audit_context(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
END;
$$;
COMMENT ON FUNCTION public.set_audit_context(uuid) IS
  'Sets the audit context user ID for service-role operations. Call this before DML operations '
  'that need to be attributed to a specific user in audit logs. Automatically cleared at transaction end.';
-------------------------------------------------------------------------------
-- 5. HELPER FUNCTION: Clear audit context
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.clear_audit_context()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM set_config('app.current_user_id', '', true);
END;
$$;
COMMENT ON FUNCTION public.clear_audit_context() IS
  'Clears the audit context user ID. Useful for long-running transactions or explicit cleanup.';
