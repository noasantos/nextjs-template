-- Fix outbound DELETE enqueue logic for Google Calendar sync.
-- User-triggered deletes must enqueue even when OLD.sync_origin was set to 'system'
-- by previous successful sync operations.

CREATE OR REPLACE FUNCTION public.enqueue_event_for_google_sync_v3()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, pgmq
LANGUAGE plpgsql
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
