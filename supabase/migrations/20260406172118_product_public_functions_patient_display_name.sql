-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:19Z

SET check_function_bodies = false;

--
-- Name: generate_patient_display_name(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_patient_display_name() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
DECLARE
  source_name TEXT;
BEGIN
  source_name := COALESCE(NULLIF(btrim(NEW.manual_preferred_name), ''), NEW.manual_first_name);
  NEW.manual_display_name := public.compute_short_display_name(source_name, NEW.manual_last_name);
  RETURN NEW;
END;
$$;

--
-- Name: generate_public_patient_display_name(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_public_patient_display_name() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
DECLARE
  source_name TEXT;
BEGIN
  source_name := COALESCE(NULLIF(btrim(NEW.preferred_name), ''), NEW.first_name);
  NEW.display_name := public.compute_short_display_name(source_name, NEW.last_name);
  RETURN NEW;
END;
$$;

--
-- Name: get_active_patient_ids(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_active_patient_ids(p_psychologist_id uuid) RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select patient_id
  from public.psychologist_clients
  where psychologist_id = p_psychologist_id
    and status = 'active'
    and patient_id is not null;
$$;

--
-- Name: get_calendar_sync_queue_backlog(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_calendar_sync_queue_backlog() RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pgmq'
    AS $$
DECLARE
  v_count bigint;
  v_total bigint := 0;
  v_queue_name text;
BEGIN
  FOREACH v_queue_name IN ARRAY ARRAY[
    'gcal_inbound',
    'gcal_outbound',
    'gcal_maintenance',
    'calendar_sync_queue'
  ]
  LOOP
    BEGIN
      EXECUTE format('SELECT COUNT(*)::bigint FROM pgmq.%I', 'q_' || v_queue_name)
      INTO v_count;
      v_total := v_total + COALESCE(v_count, 0);
    EXCEPTION
      WHEN undefined_table THEN
        NULL;
    END;
  END LOOP;

  RETURN COALESCE(v_total, 0);
END;
$$;

--
-- Name: get_current_onboarding_phase(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_current_onboarding_phase(p_user_id uuid DEFAULT NULL::uuid) RETURNS TABLE(phase text, step_number integer, step_name text, is_complete boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
  v_state RECORD;
BEGIN
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  SELECT * INTO v_state
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = v_user_id;
  
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'not_started'::TEXT, 0::INTEGER, ''::TEXT, FALSE::BOOLEAN;
    RETURN;
  END IF;
  
  IF v_state.profile_step_completed THEN
    RETURN QUERY SELECT 'complete'::TEXT, 5::INTEGER, 'profile'::TEXT, TRUE::BOOLEAN;
  ELSIF v_state.configuration_step_completed THEN
    RETURN QUERY SELECT 'phase2'::TEXT, 4::INTEGER, 'configuration'::TEXT, FALSE::BOOLEAN;
  ELSIF v_state.payment_step_completed THEN
    RETURN QUERY SELECT 'phase1'::TEXT, 3::INTEGER, 'payment'::TEXT, FALSE::BOOLEAN;
  ELSIF v_state.professional_step_completed THEN
    RETURN QUERY SELECT 'phase1'::TEXT, 2::INTEGER, 'professional'::TEXT, FALSE::BOOLEAN;
  ELSIF v_state.identity_step_completed THEN
    RETURN QUERY SELECT 'phase1'::TEXT, 1::INTEGER, 'identity'::TEXT, FALSE::BOOLEAN;
  ELSE
    RETURN QUERY SELECT 'not_started'::TEXT, 0::INTEGER, ''::TEXT, FALSE::BOOLEAN;
  END IF;
END;
$$;

--
-- Name: FUNCTION get_current_onboarding_phase(p_user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_current_onboarding_phase(p_user_id uuid) IS 'Returns the current onboarding phase and step for a user.';

--
-- Name: get_effective_cancellation_policy(uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_effective_cancellation_policy(p_psychologist_id uuid, p_reference_timestamp timestamp with time zone DEFAULT now()) RETURNS TABLE(policy_code text, fee_percentage integer, min_notice_hours integer, effective_from timestamp with time zone, effective_until timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pscp.policy_code::TEXT,
    (rv.metadata->>'fee_percentage')::INTEGER as fee_percentage,
    (rv.metadata->>'min_notice_hours')::INTEGER as min_notice_hours,
    pscp.effective_from,
    pscp.effective_until
  FROM public.psychologist_session_cancellation_policy pscp
  JOIN public.reference_values rv 
    ON rv.value = pscp.policy_code::TEXT 
    AND rv.category = 'cancellation_policy'
  WHERE pscp.psychologist_id = p_psychologist_id
    AND p_reference_timestamp >= pscp.effective_from
    AND (pscp.effective_until IS NULL OR p_reference_timestamp < pscp.effective_until)
  ORDER BY pscp.effective_from DESC
  LIMIT 1;
END;
$$;

--
-- Name: FUNCTION get_effective_cancellation_policy(p_psychologist_id uuid, p_reference_timestamp timestamp with time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_effective_cancellation_policy(p_psychologist_id uuid, p_reference_timestamp timestamp with time zone) IS 'Retrieves the cancellation policy that was active at a specific point in time';

--
-- Name: get_jwt_claim_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_jwt_claim_role() RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select coalesce(
    (select current_setting('request.jwt.claims', true)::json->>'user_role'),
    null
  );
$$;

--
-- Name: get_net_availability(uuid, date, date, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_net_availability(p_psychologist_id uuid, p_start_date date, p_end_date date, p_slot_duration_minutes integer DEFAULT 50, p_timezone text DEFAULT 'America/Sao_Paulo'::text) RETURNS TABLE(slot_start timestamp with time zone, slot_end timestamp with time zone, duration_minutes integer, day_of_week integer, delivery_mode public.delivery_mode)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_current_date date;
  v_dow integer;
  v_range_start timestamptz;
  v_range_end timestamptz;
BEGIN
  -- Validate inputs
  IF p_end_date < p_start_date THEN
    RAISE EXCEPTION 'end_date must be >= start_date';
  END IF;
  IF p_end_date - p_start_date > 90 THEN
    RAISE EXCEPTION 'Date range cannot exceed 90 days';
  END IF;
  IF p_slot_duration_minutes < 15 OR p_slot_duration_minutes > 240 THEN
    RAISE EXCEPTION 'Slot duration must be between 15 and 240 minutes';
  END IF;

  -- Compute the full timestamptz range for the query window
  v_range_start := (p_start_date::text || ' 00:00:00')::timestamp AT TIME ZONE p_timezone;
  v_range_end := ((p_end_date + 1)::text || ' 00:00:00')::timestamp AT TIME ZONE p_timezone;

  RETURN QUERY
  WITH
  -- Step 1: Generate availability windows from weekly config
  availability_windows AS (
    SELECT
      d.day_date,
      EXTRACT(DOW FROM d.day_date)::integer AS dow,
      (d.day_date::text || ' ' || pa.start_time::text)::timestamp AT TIME ZONE p_timezone AS win_start,
      (d.day_date::text || ' ' || pa.end_time::text)::timestamp AT TIME ZONE p_timezone AS win_end,
      pa.delivery_mode AS dm
    FROM
      generate_series(p_start_date, p_end_date, '1 day'::interval) AS d(day_date),
      public.psychologist_availability pa
    WHERE
      pa.psychologist_id = p_psychologist_id
      AND pa.is_active = true
      AND pa.day_of_week = EXTRACT(DOW FROM d.day_date)::integer
      AND (pa.effective_start IS NULL OR d.day_date >= pa.effective_start)
      AND (pa.effective_end IS NULL OR d.day_date <= pa.effective_end)
  ),

  -- Step 2: Apply availability exceptions
  -- Remove days marked unavailable; add/replace windows for available exceptions
  exception_overrides AS (
    SELECT
      ae.exception_date,
      ae.is_available,
      ae.start_time,
      ae.end_time
    FROM public.availability_exceptions ae
    WHERE
      ae.psychologist_id = p_psychologist_id
      AND ae.exception_date BETWEEN p_start_date AND p_end_date
  ),

  -- Merge: remove windows on unavailable exception days,
  -- keep exception windows on available exception days
  effective_windows AS (
    -- Regular availability on non-exception days
    SELECT aw.win_start, aw.win_end, aw.dm, aw.dow
    FROM availability_windows aw
    WHERE NOT EXISTS (
      SELECT 1 FROM exception_overrides eo
      WHERE eo.exception_date = aw.day_date::date
    )

    UNION ALL

    -- Exception days with custom availability
    SELECT
      (eo.exception_date::text || ' ' || eo.start_time::text)::timestamp AT TIME ZONE p_timezone,
      (eo.exception_date::text || ' ' || eo.end_time::text)::timestamp AT TIME ZONE p_timezone,
      'hybrid'::public.delivery_mode,
      EXTRACT(DOW FROM eo.exception_date)::integer
    FROM exception_overrides eo
    WHERE eo.is_available = true
      AND eo.start_time IS NOT NULL
      AND eo.end_time IS NOT NULL
  ),

  -- Step 3: Generate discrete slots within each effective window
  candidate_slots AS (
    SELECT
      ew.win_start + (s.n * (p_slot_duration_minutes || ' minutes')::interval) AS cs_start,
      ew.win_start + ((s.n + 1) * (p_slot_duration_minutes || ' minutes')::interval) AS cs_end,
      ew.dm AS cs_dm,
      ew.dow AS cs_dow
    FROM effective_windows ew
    CROSS JOIN LATERAL generate_series(
      0,
      (EXTRACT(EPOCH FROM (ew.win_end - ew.win_start)) / (p_slot_duration_minutes * 60))::integer - 1
    ) AS s(n)
    WHERE ew.win_start + ((s.n + 1) * (p_slot_duration_minutes || ' minutes')::interval) <= ew.win_end
  ),

  -- Step 4: Subtract busy slots using range overlap
  free_slots AS (
    SELECT cs.cs_start, cs.cs_end, cs.cs_dm, cs.cs_dow
    FROM candidate_slots cs
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.busy_slots bs
      WHERE bs.psychologist_id = p_psychologist_id
        AND bs.slot_range && tstzrange(cs.cs_start, cs.cs_end, '[)')
    )
  )

  SELECT
    fs.cs_start,
    fs.cs_end,
    p_slot_duration_minutes,
    fs.cs_dow,
    fs.cs_dm
  FROM free_slots fs
  WHERE fs.cs_start >= v_range_start
    AND fs.cs_end <= v_range_end
    AND fs.cs_start >= now()
  ORDER BY fs.cs_start;
END;
$$;
