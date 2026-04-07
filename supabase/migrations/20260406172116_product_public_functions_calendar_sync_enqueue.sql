-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:16Z

SET check_function_bodies = false;

--
-- Name: enqueue_calendar_sync_job(jsonb, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enqueue_calendar_sync_job(p_payload jsonb, p_sleep_seconds integer DEFAULT 0, p_queue_name text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pgmq'
    AS $fn$
DECLARE
  v_msg_id bigint;
  v_queue_name text;
  v_connection_id uuid;
  v_reserved_connection_id uuid;
  v_action text := lower(coalesce(p_payload #>> '{event_data,action}', ''));
  v_reason text := lower(coalesce(p_payload->>'reason', ''));
  v_retry_count integer := 0;
  v_should_coalesce boolean := false;
BEGIN
  v_queue_name := public.resolve_calendar_sync_queue_name(p_payload, p_queue_name);

  IF v_queue_name = 'gcal_inbound' THEN
    BEGIN
      v_retry_count := COALESCE(NULLIF(p_payload->>'retry_count', '')::integer, 0);
    EXCEPTION
      WHEN invalid_text_representation THEN
        v_retry_count := 0;
    END;

    BEGIN
      v_connection_id := nullif(p_payload->>'connection_id', '')::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        v_connection_id := NULL;
    END;

    v_should_coalesce := (
      v_connection_id IS NOT NULL
      AND v_retry_count = 0
      AND (v_reason = 'webhook' OR v_action = 'sync_incremental')
    );

    IF v_should_coalesce THEN
      INSERT INTO public.google_sync_inbound_coalesce (connection_id, msg_id, last_enqueued_at)
      VALUES (v_connection_id, NULL, now())
      ON CONFLICT (connection_id) DO NOTHING
      RETURNING connection_id INTO v_reserved_connection_id;

      IF v_reserved_connection_id IS NULL THEN
        RETURN NULL;
      END IF;
    END IF;
  END IF;

  -- Primary backend path: pgmq schema.
  BEGIN
    EXECUTE 'SELECT pgmq.send($1, $2, $3)'
      INTO v_msg_id
      USING v_queue_name, p_payload, GREATEST(COALESCE(p_sleep_seconds, 0), 0);
  EXCEPTION
    WHEN undefined_function THEN
      -- Older extension variants may only expose send(queue_name, msg).
      EXECUTE 'SELECT pgmq.send($1, $2)'
        INTO v_msg_id
        USING v_queue_name, p_payload;
  END;

  IF v_should_coalesce AND v_connection_id IS NOT NULL THEN
    UPDATE public.google_sync_inbound_coalesce
    SET msg_id = v_msg_id,
        last_enqueued_at = now()
    WHERE connection_id = v_connection_id;
  END IF;

  RETURN v_msg_id;
EXCEPTION
  WHEN OTHERS THEN
    IF v_should_coalesce AND v_connection_id IS NOT NULL THEN
      DELETE FROM public.google_sync_inbound_coalesce
      WHERE connection_id = v_connection_id
        AND msg_id IS NULL;
    END IF;
    RAISE;
END;
$fn$;

--
-- Name: enqueue_event_for_google_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enqueue_event_for_google_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  
  IF NEW.source = 'fluri' AND NEW.google_sync_status = 'pending' THEN
    INSERT INTO sync_queue (
      psychologist_id,
      type,
      status,
      event_id,
      event_data,
      created_at,
      updated_at
    ) VALUES (
      NEW.psychologist_id,
      'fluri_to_google',
      'pending',
      NEW.id,
      jsonb_build_object(
        'event_id', NEW.id,
        'action', 'create'
      ),
      now(),
      now()
    );
    
    RAISE LOG 'Enqueued event % for Google Calendar sync', NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

--
-- Name: enqueue_event_for_google_sync_v3(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enqueue_event_for_google_sync_v3() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pgmq'
    AS $$
DECLARE
  v_action text;
  v_event_id uuid;
  v_psychologist_id uuid;
  v_google_event_id text;
  v_connection_id uuid;
  v_idempotency_key text;
  v_sync_enabled boolean := false;
  v_payload jsonb;
  v_series_id uuid;
  v_original_start_datetime timestamptz;
  v_all_day boolean;
  v_timezone text;
  v_title text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.sync_origin <> 'user' THEN
      RETURN NEW;
    END IF;
    v_action := 'create';
    v_event_id := NEW.id;
    v_psychologist_id := NEW.psychologist_id;
    v_google_event_id := NEW.google_event_id;
    v_series_id := NEW.series_id;
    v_original_start_datetime := NEW.original_start_datetime;
    v_all_day := NEW.all_day;
    v_timezone := NEW.timezone;
    v_title := NEW.title;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.sync_origin <> 'user' THEN
      RETURN NEW;
    END IF;

    IF NOT (
      ROW(
        NEW.title,
        NEW.description,
        NEW.location,
        NEW.color,
        NEW.start_datetime,
        NEW.end_datetime,
        NEW.duration_minutes,
        NEW.timezone,
        NEW.all_day,
        NEW.status,
        NEW.metadata
      ) IS DISTINCT FROM
      ROW(
        OLD.title,
        OLD.description,
        OLD.location,
        OLD.color,
        OLD.start_datetime,
        OLD.end_datetime,
        OLD.duration_minutes,
        OLD.timezone,
        OLD.all_day,
        OLD.status,
        OLD.metadata
      )
    ) THEN
      RETURN NEW;
    END IF;

    v_action := CASE WHEN OLD.google_event_id IS NULL THEN 'create' ELSE 'update' END;
    v_event_id := NEW.id;
    v_psychologist_id := NEW.psychologist_id;
    v_google_event_id := NEW.google_event_id;
    v_series_id := NEW.series_id;
    v_original_start_datetime := NEW.original_start_datetime;
    v_all_day := NEW.all_day;
    v_timezone := NEW.timezone;
    v_title := NEW.title;
  ELSIF TG_OP = 'DELETE' THEN
    -- Intentionally do not gate by OLD.sync_origin.
    -- On DELETE there is no NEW row to stamp origin, so OLD.sync_origin may still be
    -- 'system' from prior sync operations even when the current delete is user initiated.
    v_action := 'delete';
    v_event_id := OLD.id;
    v_psychologist_id := OLD.psychologist_id;
    v_google_event_id := OLD.google_event_id;
    v_series_id := OLD.series_id;
    v_original_start_datetime := OLD.original_start_datetime;
    v_all_day := OLD.all_day;
    v_timezone := OLD.timezone;
    v_title := OLD.title;
  ELSE
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT id, (is_connected AND sync_enabled AND sync_to_google)
    INTO v_connection_id, v_sync_enabled
  FROM public.google_calendar_connections
  WHERE psychologist_id = v_psychologist_id
  LIMIT 1;

  IF v_connection_id IS NULL OR NOT COALESCE(v_sync_enabled, false) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  v_idempotency_key := md5(
    concat_ws(
      ':',
      v_psychologist_id::text,
      v_event_id::text,
      v_action,
      COALESCE(v_google_event_id, ''),
      date_trunc('minute', now())::text
    )
  );

  v_payload := jsonb_build_object(
    'job_type', 'outbound',
    'direction', 'fluri_to_google',
    'psychologist_id', v_psychologist_id,
    'connection_id', v_connection_id,
    'event_id', v_event_id,
    'idempotency_key', v_idempotency_key,
    'reason', 'calendar_event_' || lower(TG_OP),
    'retry_count', 0,
    'max_retries', 5,
    'event_data', jsonb_build_object(
      'action', v_action,
      'source', 'db_trigger',
      'event_id', v_event_id,
      'google_event_id', v_google_event_id,
      'connection_id', v_connection_id,
      'reason', 'calendar_event_' || lower(TG_OP),
      'series_id', v_series_id,
      'occurrence_key', CASE
        WHEN v_series_id IS NULL OR v_original_start_datetime IS NULL THEN NULL
        ELSE concat(v_series_id::text, ':', to_char(v_original_start_datetime, 'YYYY-MM-DD"T"HH24:MI:SSOF'))
      END,
      'delete_scope', CASE WHEN v_series_id IS NULL THEN 'single' ELSE 'occurrence' END,
      'all_day', v_all_day,
      'timezone', v_timezone,
      'title_base', v_title
    )
  );

  PERFORM public.enqueue_calendar_sync_job(v_payload, 0);

  RETURN COALESCE(NEW, OLD);
END;
$$;

--
-- Name: ensure_psychologist_for_current_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_psychologist_for_current_user() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  insert into public.user_psychologists (id)
  values (v_user_id)
  on conflict (id) do nothing;
end;
$$;

--
-- Name: FUNCTION ensure_psychologist_for_current_user(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.ensure_psychologist_for_current_user() IS 'Ensures a psychologist record exists for the current user (used by triggers)';

--
-- Name: fn_close_previous_cancellation_policy(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_close_previous_cancellation_policy() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    UPDATE public.psychologist_session_cancellation_policy
    SET effective_until = NOW()
    WHERE psychologist_id = NEW.psychologist_id AND effective_until IS NULL AND id <> NEW.id;
    RETURN NEW;
END;
$$;
