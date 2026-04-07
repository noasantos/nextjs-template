-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:02Z

SET check_function_bodies = false;

--
-- Name: check_configuration_prerequisites(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_configuration_prerequisites(p_psychologist_id uuid) RETURNS TABLE(has_services boolean, has_locations boolean, has_online_delivery boolean, has_availability boolean, all_prerequisites_met boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  WITH 
  services_check AS (
    SELECT EXISTS (
      SELECT 1 FROM psychologist_services 
      WHERE psychologist_id = p_psychologist_id AND is_active = true
    ) AS has_services
  ),
  locations_check AS (
    SELECT EXISTS (
      SELECT 1 FROM public_locations 
      WHERE psychologist_id = p_psychologist_id AND is_active = true
    ) AS has_locations
  ),
  online_check AS (
    SELECT EXISTS (
      SELECT 1 FROM psychologist_weekly_schedules 
      WHERE psychologist_id = p_psychologist_id 
        AND delivery_mode IN ('telehealth', 'hybrid') 
        AND is_active = true
    ) AS has_online_delivery
  ),
  availability_check AS (
    SELECT EXISTS (
      SELECT 1 FROM psychologist_weekly_schedules 
      WHERE psychologist_id = p_psychologist_id AND is_active = true
    ) AS has_availability
  )
  SELECT 
    s.has_services,
    l.has_locations,
    o.has_online_delivery,
    a.has_availability,
    (s.has_services AND (l.has_locations OR o.has_online_delivery) AND a.has_availability) AS all_prerequisites_met
  FROM services_check s, locations_check l, online_check o, availability_check a;
END;
$$;

--
-- Name: FUNCTION check_configuration_prerequisites(p_psychologist_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.check_configuration_prerequisites(p_psychologist_id uuid) IS 'Validates that a psychologist has met all prerequisites before completing Phase 2 onboarding:
   - At least 1 active service
   - At least 1 active location OR online delivery enabled (telehealth/hybrid in schedules)
   - At least 1 active availability slot';

--
-- Name: check_file_size(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_file_size() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
BEGIN
  IF NEW.bucket_id = 'patient-documents'
     AND COALESCE((NEW.metadata->>'size')::bigint, 0) > 10485760 THEN
    RAISE EXCEPTION 'File too large. Maximum size is 10MB';
  END IF;
  RETURN NEW;
END;
$$;

--
-- Name: check_profile_completion(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_profile_completion(p_psychologist_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  completion_score integer := 0;
  max_score integer := 8;
BEGIN
  SELECT
    CASE WHEN display_name IS NOT NULL AND length(trim(display_name)) > 0 THEN 1 ELSE 0 END +
    CASE WHEN bio IS NOT NULL AND length(trim(bio)) > 50 THEN 1 ELSE 0 END +
    CASE WHEN avatar_url IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN array_length(specialties, 1) > 0 THEN 1 ELSE 0 END +
    CASE WHEN array_length(therapeutic_approaches, 1) > 0 THEN 1 ELSE 0 END +
    CASE WHEN EXISTS (
      SELECT 1 FROM public.psychologist_availability pa
      WHERE pa.psychologist_id = p_psychologist_id AND pa.is_active = true
    ) THEN 1 ELSE 0 END +
    CASE WHEN city IS NOT NULL AND state IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN languages IS NOT NULL AND array_length(languages, 1) > 0 THEN 1 ELSE 0 END
  INTO completion_score
  FROM public.psychologist_profiles
  WHERE id = p_psychologist_id;

  UPDATE public.psychologist_profiles
  SET profile_completed = (completion_score >= 6)
  WHERE id = p_psychologist_id;

  RETURN completion_score >= 6;
END;
$$;

--
-- Name: check_slot_available(uuid, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_slot_available(p_psychologist_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT NOT EXISTS (
    SELECT 1
    FROM public.busy_slots
    WHERE psychologist_id = p_psychologist_id
      AND slot_range && tstzrange(p_start_time, p_end_time, '[)')
      AND is_hard_block = true
  );
$$;

--
-- Name: check_subscription_access(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_subscription_access(p_therapist_id uuid) RETURNS TABLE(status text, has_access boolean, trial_end timestamp with time zone, current_period_end timestamp with time zone, days_remaining integer, is_in_grace_period boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_sub record;
  v_grace_period interval := interval '3 days';
begin
  select * into v_sub
  from public.psychologist_subscriptions
  where psychologist_id = p_therapist_id;
  
  if not found then
    return query select 
      'inactive'::text,
      false,
      null::timestamptz,
      null::timestamptz,
      0,
      false;
    return;
  end if;
  
  return query select
    v_sub.status,
    v_sub.has_active_subscription or 
      (v_sub.current_period_end is not null and v_sub.current_period_end + v_grace_period > now()),
    v_sub.trial_ends_at,
    v_sub.current_period_end,
    case 
      when v_sub.current_period_end is null then 0
      else greatest(0, extract(day from v_sub.current_period_end - now()))::integer
    end,
    v_sub.current_period_end is not null and 
      v_sub.current_period_end < now() and 
      v_sub.current_period_end + v_grace_period > now();
end;
$$;

--
-- Name: check_sync_lock(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_sync_lock(p_lock_key text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  return exists (
    select 1 from public.sync_locks
    where lock_key = p_lock_key
      and expires_at > now()
  );
end;
$$;

--
-- Name: cleanup_expired_idempotency_keys(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_expired_idempotency_keys() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  delete from public.google_sync_idempotency
  where expires_at < now();
end;
$$;

--
-- Name: cleanup_expired_idempotency_records(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_expired_idempotency_records() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  DELETE FROM public.stripe_idempotency_log
  WHERE expires_at < now();
END;
$$;

--
-- Name: cleanup_expired_patient_deletions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_expired_patient_deletions() RETURNS TABLE(deleted_count integer, cleanup_timestamp timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_deleted_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  -- Delete expired patients
  WITH deleted_patients AS (
    DELETE FROM public.psychologist_clients
    WHERE deleted_at IS NOT NULL
      AND recovery_deadline IS NOT NULL
      AND recovery_deadline < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_deleted_count
  FROM deleted_patients;
  
  -- Log to audit table if it exists
  BEGIN
    INSERT INTO public.patient_deletion_audit_log (
      cleanup_timestamp,
      deleted_count,
      triggered_by,
      notes
    ) VALUES (
      v_timestamp,
      v_deleted_count,
      COALESCE(current_setting('app.triggered_by', true), 'manual_or_cron'),
      format('Cleanup removendo %s paciente(s) com prazo expirado', v_deleted_count)
    );
  EXCEPTION WHEN OTHERS THEN
    -- If audit log fails, just log a notice but don't fail the function
    RAISE NOTICE 'Could not write to audit log: %', SQLERRM;
  END;
  
  -- Log completion
  RAISE NOTICE 'Patient deletion cleanup completed at %. Deleted % expired patient(s).', 
    v_timestamp, v_deleted_count;
  
  -- Return results
  RETURN QUERY SELECT v_deleted_count, v_timestamp;
END;
$$;

--
-- Name: cleanup_expired_sync_locks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_expired_sync_locks() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  delete from public.sync_locks where expires_at <= now();
end;
$$;

--
-- Name: cleanup_old_audit_logs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_old_audit_logs() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  DELETE FROM public.service_role_audit_log
  WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$;

--
-- Name: cleanup_old_audit_logs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_old_audit_logs(p_retention_days integer DEFAULT 1825) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM public.audit_logs
  WHERE created_at < NOW() - (p_retention_days || ' days')::INTERVAL;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN v_deleted_count;
END;
$$;

--
-- Name: FUNCTION cleanup_old_audit_logs(p_retention_days integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cleanup_old_audit_logs(p_retention_days integer) IS 'Removes audit logs older than the specified retention period. Default is 5 years (LGPD/GDPR compliance).';

--
-- Name: clear_audit_context(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_audit_context() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  PERFORM set_config('app.current_user_id', '', true);
END;
$$;
