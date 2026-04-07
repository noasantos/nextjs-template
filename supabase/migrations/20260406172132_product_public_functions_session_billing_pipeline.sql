-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:32Z

SET check_function_bodies = false;

--
-- Name: process_pending_session_billing(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_pending_session_billing(p_batch_size integer DEFAULT 100) RETURNS TABLE(processed_count integer, success_count integer, error_count integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
        DECLARE
          v_processed INTEGER := 0;
          v_success INTEGER := 0;
          v_errors INTEGER := 0;
          v_session RECORD;
        BEGIN
          FOR v_session IN
            SELECT pcs.id as session_id, pcs.psychologist_id, pcs.billing_status, pcs.billing_next_attempt_at,
              pcs.charge_id, pc.price_cents, pc.description, pcs.automation_metadata
            FROM public.psychologist_clinical_sessions pcs
            LEFT JOIN public.psychologist_patient_charges pc ON pc.id = pcs.charge_id
            WHERE pcs.billing_status IN ('pending', 'failed')
              AND (pcs.billing_next_attempt_at IS NULL OR pcs.billing_next_attempt_at <= NOW())
              AND pcs.billing_attempt_count < 3
            ORDER BY pcs.billing_next_attempt_at ASC
            LIMIT p_batch_size
          LOOP
            v_processed := v_processed + 1;
            BEGIN
              UPDATE public.psychologist_clinical_sessions
              SET billing_attempt_count = COALESCE(billing_attempt_count, 0) + 1,
                billing_next_attempt_at = CASE 
                  WHEN billing_attempt_count >= 2 THEN NULL
                  ELSE NOW() + (INTERVAL '1 hour' * POWER(2, COALESCE(billing_attempt_count, 0)))
                END,
                automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
                  'last_billing_attempt', NOW(),
                  'billing_attempt_' || COALESCE(billing_attempt_count, 0) + 1, jsonb_build_object('status', 'processing', 'timestamp', NOW())
                )
              WHERE id = v_session.session_id;
              v_success := v_success + 1;
            EXCEPTION WHEN OTHERS THEN
              v_errors := v_errors + 1;
              UPDATE public.psychologist_clinical_sessions
              SET billing_last_error = SQLERRM,
                automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
                  'last_billing_error', jsonb_build_object('message', SQLERRM, 'timestamp', NOW())
                )
              WHERE id = v_session.session_id;
            END;
          END LOOP;
          
          RETURN QUERY SELECT v_processed, v_success, v_errors;
        END;
        $$;

--
-- Name: FUNCTION process_pending_session_billing(p_batch_size integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.process_pending_session_billing(p_batch_size integer) IS 'Processes billing for sessions with pending or failed billing status. Uses exponential backoff for retries.';

--
-- Name: process_pending_session_billing(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_pending_session_billing(p_limit integer DEFAULT 200, p_lead_days integer DEFAULT 7) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_candidate record;
  v_result jsonb;
  v_processed integer := 0;
  v_charged integer := 0;
  v_failed integer := 0;
  v_skipped integer := 0;
begin
  for v_candidate in
    with candidates as (
      select
        cs.id as session_id,
        cs.psychologist_id
      from public.clinical_session_details sd
      join public.psychologist_clinical_sessions cs
        on cs.id = sd.clinical_session_id
      where sd.clinical_session_id is not null
        and sd.billing_status in ('pending', 'pending_window', 'ready_to_charge', 'charge_failed')
        and cs.status not in ('cancelled', 'no_show')
        and coalesce(cs.snapshot_price_cents, 0) > 0
        and cs.start_time <= (now() + make_interval(days => p_lead_days))
        and (sd.billing_next_attempt_at is null or sd.billing_next_attempt_at <= now())
      order by cs.start_time asc
      limit p_limit
      for update of sd skip locked
    )
    select * from candidates
  loop
    v_processed := v_processed + 1;

    v_result := public.create_session_charge_if_due(
      v_candidate.session_id,
      v_candidate.psychologist_id,
      p_lead_days,
      false,
      format('charge:session:%s:v1', v_candidate.session_id)
    );

    if coalesce(v_result ->> 'reason', '') = 'error' then
      v_failed := v_failed + 1;
    elsif nullif(v_result ->> 'charge_id', '') is not null then
      v_charged := v_charged + 1;
    else
      v_skipped := v_skipped + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'processed', v_processed,
    'charged', v_charged,
    'failed', v_failed,
    'skipped', v_skipped,
    'lead_days', p_lead_days,
    'limit', p_limit,
    'processed_at', now()
  );
end;
$$;

--
-- Name: provision_user_role(uuid, public.app_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.provision_user_role(p_user_id uuid, p_role public.app_role) RETURNS public.app_role
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_existing_role public.app_role;
begin
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
  
  select role into v_existing_role from public.user_roles where user_id = p_user_id;
  if v_existing_role is not null then
    return v_existing_role;
  end if;
  
  insert into public.user_roles (user_id, role) values (p_user_id, p_role);
  
  case p_role
    when 'psychologist' then
      insert into public.user_psychologists (id, subscription_status, onboarding_completed)
      values (p_user_id, 'inactive', false) on conflict (id) do nothing;
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

--
-- Name: FUNCTION provision_user_role(p_user_id uuid, p_role public.app_role); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.provision_user_role(p_user_id uuid, p_role public.app_role) IS 'Provisions a user role and creates the corresponding identity record. Sets app.current_user_id session variable for audit logging.';

--
-- Name: query_audit_logs(text, text, text, uuid, timestamp with time zone, timestamp with time zone, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.query_audit_logs(p_table_name text DEFAULT NULL::text, p_record_id text DEFAULT NULL::text, p_action text DEFAULT NULL::text, p_user_id uuid DEFAULT NULL::uuid, p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 100) RETURNS TABLE(id uuid, user_id uuid, user_type text, table_name text, record_id text, action text, changed_fields jsonb, correlation_id uuid, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    al.id,
    al.user_id,
    al.user_type,
    al.table_name,
    al.record_id,
    al.action,
    al.changed_fields,
    al.correlation_id,
    al.created_at
  FROM public.audit_logs al
  WHERE (p_table_name IS NULL OR al.table_name = p_table_name)
    AND (p_record_id IS NULL OR al.record_id = p_record_id)
    AND (p_action IS NULL OR al.action = p_action)
    AND (p_user_id IS NULL OR al.user_id = p_user_id)
    AND (p_start_date IS NULL OR al.created_at >= p_start_date)
    AND (p_end_date IS NULL OR al.created_at <= p_end_date)
  ORDER BY al.created_at DESC
  LIMIT p_limit;
END;
$$;

--
-- Name: FUNCTION query_audit_logs(p_table_name text, p_record_id text, p_action text, p_user_id uuid, p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_limit integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.query_audit_logs(p_table_name text, p_record_id text, p_action text, p_user_id uuid, p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_limit integer) IS 'Query audit logs with optional filtering. Used for compliance reporting and investigation.';

--
-- Name: recalculate_daily_consolidation_for_charge(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recalculate_daily_consolidation_for_charge(p_charge_id uuid) RETURNS TABLE(action text, entry_id uuid, entry_date date, amount_cents integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
        DECLARE
          v_psychologist_id UUID;
          v_session_date DATE;
        BEGIN
          SELECT c.psychologist_id, s.start_time::date
          INTO v_psychologist_id, v_session_date
          FROM public.psychologist_patient_charges c
          JOIN public.psychologist_clinical_sessions s ON s.id = c.session_id
          WHERE c.id = p_charge_id;
          
          IF v_psychologist_id IS NULL THEN
            RETURN;
          END IF;
          
          RETURN QUERY SELECT * FROM public.consolidate_daily_charges(v_psychologist_id, v_session_date);
        END;
        $$;

--
-- Name: release_google_sync_inbound_coalesce(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.release_google_sync_inbound_coalesce(p_connection_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  DELETE FROM public.google_sync_inbound_coalesce
  WHERE connection_id = p_connection_id;
END;
$$;

--
-- Name: release_sync_lock(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.release_sync_lock(p_lock_key text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  delete from public.sync_locks where lock_key = p_lock_key;
end;
$$;

--
-- Name: request_account_deletion(text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.request_account_deletion(p_reason text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_user_id uuid;
  v_request_id uuid;
  v_correlation_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT correlation_id
    INTO v_correlation_id
  FROM public.account_deletion_requests
  WHERE user_id = v_user_id
    AND status IN ('requested', 'approved', 'processing')
  ORDER BY requested_at DESC
  LIMIT 1;

  IF v_correlation_id IS NOT NULL THEN
    RAISE EXCEPTION 'An active account deletion request already exists';
  END IF;

  INSERT INTO public.account_deletion_requests (
    user_id,
    requested_by,
    reason,
    status,
    metadata
  )
  VALUES (
    v_user_id,
    v_user_id,
    p_reason,
    'requested',
    COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING id, correlation_id INTO v_request_id, v_correlation_id;

  PERFORM public.log_security_audit_event(
    v_user_id,
    'account_deletion_requested',
    'user',
    v_user_id::text,
    jsonb_build_object(
      'request_id', v_request_id,
      'reason', p_reason
    ),
    v_correlation_id,
    'rpc'
  );

  RETURN v_request_id;
END;
$$;
