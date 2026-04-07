-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:35Z

SET check_function_bodies = false;

--
-- Name: resolve_calendar_sync_queue_name(jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_calendar_sync_queue_name(p_payload jsonb, p_queue_name text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_queue_name text := lower(coalesce(p_queue_name, ''));
  v_job_type text := lower(coalesce(p_payload->>'job_type', ''));
  v_direction text := lower(coalesce(p_payload->>'direction', ''));
  v_reason text := lower(coalesce(p_payload->>'reason', ''));
BEGIN
  IF v_queue_name IN ('gcal_inbound', 'gcal_outbound', 'gcal_maintenance') THEN
    RETURN v_queue_name;
  END IF;

  IF v_job_type IN ('inbound', 'google_to_fluri') THEN
    RETURN 'gcal_inbound';
  END IF;

  IF v_job_type IN ('outbound', 'fluri_to_google') THEN
    RETURN 'gcal_outbound';
  END IF;

  IF v_job_type = 'maintenance' THEN
    RETURN 'gcal_maintenance';
  END IF;

  IF v_direction = 'fluri_to_google' THEN
    RETURN 'gcal_outbound';
  END IF;

  IF v_reason IN ('periodic_drift_audit', 'watch_gap_recovery', 'watch_expired_recovery') THEN
    RETURN 'gcal_maintenance';
  END IF;

  RETURN 'gcal_inbound';
END;
$$;

--
-- Name: schedule_all_capitals_holiday_sync(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.schedule_all_capitals_holiday_sync(p_year integer) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    capital RECORD;
    capitals JSONB;
BEGIN
    -- List of Brazilian capitals (UF and City Name)
    capitals := '[
        {"state": "AC", "city": "Rio Branco"},
        {"state": "AL", "city": "Maceió"},
        {"state": "AP", "city": "Macapá"},
        {"state": "AM", "city": "Manaus"},
        {"state": "BA", "city": "Salvador"},
        {"state": "CE", "city": "Fortaleza"},
        {"state": "DF", "city": "Brasília"},
        {"state": "ES", "city": "Vitória"},
        {"state": "GO", "city": "Goiânia"},
        {"state": "MA", "city": "São Luís"},
        {"state": "MT", "city": "Cuiabá"},
        {"state": "MS", "city": "Campo Grande"},
        {"state": "MG", "city": "Belo Horizonte"},
        {"state": "PA", "city": "Belém"},
        {"state": "PB", "city": "João Pessoa"},
        {"state": "PR", "city": "Curitiba"},
        {"state": "PE", "city": "Recife"},
        {"state": "PI", "city": "Teresina"},
        {"state": "RJ", "city": "Rio de Janeiro"},
        {"state": "RN", "city": "Natal"},
        {"state": "RS", "city": "Porto Alegre"},
        {"state": "RO", "city": "Porto Velho"},
        {"state": "RR", "city": "Boa Vista"},
        {"state": "SC", "city": "Florianópolis"},
        {"state": "SP", "city": "São Paulo"},
        {"state": "SE", "city": "Aracaju"},
        {"state": "TO", "city": "Palmas"}
    ]'::jsonb;

    FOR capital IN SELECT * FROM jsonb_to_recordset(capitals) AS x(state text, city text)
    LOOP
        PERFORM cron.schedule(
            'sync-holidays-' || lower(capital.state) || '-' || replace(lower(capital.city), ' ', '-'),
            '0 3 1 1 *', -- 03:00 on January 1st
            format(
                'SELECT net.http_post(url := %L, headers := %L)',
                'https://' || current_setting('request.headers')::jsonb->>'host' || '/functions/v1/sync-holidays?year=' || p_year || '&state=' || capital.state || '&city=' || urlencode(capital.city),
                jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'))
            )
        );
    END LOOP;
END;
$$;

--
-- Name: FUNCTION schedule_all_capitals_holiday_sync(p_year integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.schedule_all_capitals_holiday_sync(p_year integer) IS 'Helper to schedule holiday synchronization for all Brazilian capitals.';

--
-- Name: set_audit_context(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_audit_context(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
END;
$$;

--
-- Name: FUNCTION set_audit_context(p_user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.set_audit_context(p_user_id uuid) IS 'Sets the audit context user ID for service-role operations. Call this before DML operations that need to be attributed to a specific user in audit logs. Automatically cleared at transaction end.';

--
-- Name: set_psychologist_cancellation_policy(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_psychologist_cancellation_policy(p_psychologist_id uuid, p_policy_code text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_valid_policy BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.reference_values 
    WHERE category = 'cancellation_policy' AND value = p_policy_code AND is_active = true
  ) INTO v_valid_policy;
  
  IF NOT v_valid_policy THEN
    RAISE EXCEPTION 'Invalid cancellation policy code: %', p_policy_code;
  END IF;
  
  INSERT INTO public.psychologist_session_cancellation_policy (psychologist_id, policy_code, effective_from)
  VALUES (p_psychologist_id, p_policy_code::public.cancellation_policy_code, NOW());
  
  RETURN TRUE;
END;
$$;

--
-- Name: FUNCTION set_psychologist_cancellation_policy(p_psychologist_id uuid, p_policy_code text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.set_psychologist_cancellation_policy(p_psychologist_id uuid, p_policy_code text) IS 'Sets a new cancellation policy for a psychologist (inserts new version)';

--
-- Name: stamp_calendar_event_sync_origin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stamp_calendar_event_sync_origin() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF auth.role() IS NOT NULL AND auth.role() <> 'service_role' THEN
    NEW.sync_origin := 'user';
  END IF;

  RETURN NEW;
END;
$$;

--
-- Name: sync_calendar_event_to_busy_slots(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_calendar_event_to_busy_slots() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_slot_range tstzrange;
  v_is_hard_block boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.busy_slots
    WHERE source_type = 'calendar_event' AND source_id = OLD.id;
    RETURN OLD;
  END IF;

  v_slot_range := tstzrange(NEW.start_datetime, NEW.end_datetime, '[)');
  v_is_hard_block := NEW.event_type IN ('session', 'block', 'supervision');

  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.status IN ('cancelled', 'rescheduled') THEN
      DELETE FROM public.busy_slots
      WHERE source_type = 'calendar_event' AND source_id = NEW.id;
    ELSE
      -- CRITICAL FIX: If we are inserting a session event, first remove any clinical_session slot 
      -- that might have been created by a previous step in the same transaction 
      -- (common in create_session_with_calendar RPC)
      IF NEW.event_type = 'session' THEN
        DELETE FROM public.busy_slots
        WHERE psychologist_id = NEW.psychologist_id
          AND slot_range = v_slot_range
          AND source_type = 'clinical_session';
      END IF;

      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        NEW.psychologist_id,
        v_slot_range,
        'calendar_event',
        NEW.id,
        NEW.event_type,
        v_is_hard_block,
        NEW.title
      )
      ON CONFLICT (source_type, source_id) DO UPDATE SET
        psychologist_id = EXCLUDED.psychologist_id,
        slot_range = EXCLUDED.slot_range,
        event_type = EXCLUDED.event_type,
        is_hard_block = EXCLUDED.is_hard_block,
        title = EXCLUDED.title;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;

--
-- Name: sync_calendar_event_to_session(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_calendar_event_to_session(p_event_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_event RECORD;
  v_session_id UUID;
BEGIN
  SELECT ce.id, ce.start_datetime, ce.end_datetime, ce.psychologist_id, pcs.id as existing_session_id
  INTO v_event
  FROM public.calendar_events ce
  LEFT JOIN public.psychologist_clinical_sessions pcs ON pcs.calendar_event_id = ce.id
  WHERE ce.id = p_event_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  IF v_event.existing_session_id IS NOT NULL THEN
    UPDATE public.psychologist_clinical_sessions
    SET start_time = v_event.start_datetime, end_time = v_event.end_datetime, updated_at = NOW()
    WHERE id = v_event.existing_session_id;
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$;

--
-- Name: FUNCTION sync_calendar_event_to_session(p_event_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sync_calendar_event_to_session(p_event_id uuid) IS 'Syncs a calendar event time to its associated clinical session';
