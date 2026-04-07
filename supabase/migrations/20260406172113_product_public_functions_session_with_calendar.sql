-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:13Z

SET check_function_bodies = false;

--
-- Name: create_session_with_calendar(uuid, uuid, timestamp with time zone, integer, uuid, uuid, text, integer, text, text, text, uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_session_with_calendar(p_psychologist_id uuid, p_patient_id uuid, p_start_time timestamp with time zone, p_duration_minutes integer DEFAULT 50, p_service_id uuid DEFAULT NULL::uuid, p_location_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text, p_custom_price_cents integer DEFAULT NULL::integer, p_status text DEFAULT NULL::text, p_recurrence_rule text DEFAULT NULL::text, p_timezone text DEFAULT 'America/Sao_Paulo'::text, p_session_type_id uuid DEFAULT NULL::uuid, p_session_number integer DEFAULT NULL::integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.create_session_occurrence_atomic(
    p_psychologist_id => p_psychologist_id,
    p_patient_id => p_patient_id,
    p_start_time => p_start_time,
    p_duration_minutes => p_duration_minutes,
    p_service_id => p_service_id,
    p_location_id => p_location_id,
    p_notes => p_notes,
    p_custom_price_cents => p_custom_price_cents,
    p_status => p_status,
    p_recurrence_rule => p_recurrence_rule,
    p_timezone => p_timezone,
    p_session_type_id => p_session_type_id,
    p_session_number => p_session_number
  );

  RETURN jsonb_build_object(
    'session_id', v_result ->> 'session_id',
    'event_id', v_result ->> 'event_id',
    'note_id', v_result ->> 'note_id',
    'details_id', v_result ->> 'details_id',
    'charge_id', v_result ->> 'charge_id',
    'status', v_result ->> 'status',
    'effective_price', (v_result ->> 'effective_price')::integer,
    'billing_eligible_now', COALESCE((v_result ->> 'billing_eligible_now')::boolean, false),
    'billing_pending', COALESCE((v_result ->> 'billing_pending')::boolean, false)
  );
END;
$$;

--
-- Name: current_user_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_role() RETURNS public.app_role
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select role
  from public.user_roles
  where user_id = (select auth.uid())
  limit 1;
$$;

--
-- Name: decrypt_token_base64(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.decrypt_token_base64(encrypted_token_base64 text, encryption_key text) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
  SELECT extensions.pgp_sym_decrypt(decode(encrypted_token_base64, 'base64'), encryption_key)::text;
$$;

--
-- Name: decrypt_token_base64_secure(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.decrypt_token_base64_secure(encrypted_token_base64 text, encryption_key text, p_context text DEFAULT 'unknown'::text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  decrypted TEXT;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  -- Perform decryption using the original function
  -- We assume public.decrypt_token_base64 still exists and is granted to service_role
  SELECT public.decrypt_token_base64(encrypted_token_base64, encryption_key) INTO decrypted;
  
  -- Log successful decryption
  INSERT INTO public.encryption_audit_log (
    operation,
    success,
    caller_user_id,
    context
  ) VALUES (
    'decrypt',
    true,
    v_user_id,
    p_context
  );
  
  RETURN decrypted;
EXCEPTION WHEN OTHERS THEN
  -- Log failed decryption
  INSERT INTO public.encryption_audit_log (
    operation,
    success,
    error_message,
    caller_user_id,
    context
  ) VALUES (
    'decrypt',
    false,
    SQLERRM,
    v_user_id,
    p_context
  );
  RAISE;
END;
$$;

--
-- Name: detect_high_volume_service_role_usage(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.detect_high_volume_service_role_usage(threshold integer, window_minutes integer) RETURNS TABLE(source text, operation_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT sra.source, COUNT(*) as operation_count
  FROM public.service_role_audit_log sra
  WHERE sra.created_at > NOW() - (window_minutes || ' minutes')::INTERVAL
  GROUP BY sra.source
  HAVING COUNT(*) > threshold;
END;
$$;

--
-- Name: detect_suspicious_error_patterns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.detect_suspicious_error_patterns() RETURNS TABLE(source text, error_message text, error_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT sra.source, sra.error_message, COUNT(*) as error_count
  FROM public.service_role_audit_log sra
  WHERE sra.success = false AND sra.created_at > NOW() - INTERVAL '1 hour'
  GROUP BY sra.source, sra.error_message
  HAVING COUNT(*) > 10;
END;
$$;

--
-- Name: detect_unusual_table_access(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.detect_unusual_table_access(whitelisted_tables text[]) RETURNS TABLE(source text, table_name text, access_count bigint)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT sra.source, sra.table_name, COUNT(*) as access_count
  FROM public.service_role_audit_log sra
  WHERE sra.table_name IS NOT NULL
    AND NOT (sra.table_name = ANY(whitelisted_tables))
    AND sra.created_at > NOW() - INTERVAL '24 hours'
  GROUP BY sra.source, sra.table_name;
END;
$$;

--
-- Name: empty_lexical_state_base64(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.empty_lexical_state_base64() RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select encode('{"root":{"children":[{"children":[],"direction":null,"format":"","indent":0,"type":"paragraph","version":1}],"direction":null,"format":"","indent":0,"type":"root","version":1}}'::bytea, 'base64');
$$;

--
-- Name: encrypt_token_base64(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.encrypt_token_base64(token text, encryption_key text) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO ''
    AS $$
  SELECT encode(extensions.pgp_sym_encrypt(token, encryption_key), 'base64');
$$;

--
-- Name: enforce_linktree_active_limit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_linktree_active_limit() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  active_count integer;
BEGIN
  IF NEW.is_active IS TRUE THEN
    SELECT COUNT(*)
      INTO active_count
      FROM public.public_linktree_links
     WHERE psychologist_id = NEW.psychologist_id
       AND is_active = TRUE
       AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000');

    IF active_count >= 4 THEN
      RAISE EXCEPTION 'Maximum of 4 active links allowed'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

--
-- Name: FUNCTION enforce_linktree_active_limit(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.enforce_linktree_active_limit() IS 'Enforces a maximum of 4 active links per psychologist. Fixed to reference public_linktree_links table.';

--
-- Name: enforce_rls_on_new_table(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_rls_on_new_table() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
    WHERE object_type = 'table'
  LOOP
    IF obj.schema_name = 'public' THEN
      EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', obj.object_identity);
      RAISE NOTICE '[2026 Security] RLS automatically enabled on new table: %', obj.object_identity;
    END IF;
  END LOOP;
END;
$$;
