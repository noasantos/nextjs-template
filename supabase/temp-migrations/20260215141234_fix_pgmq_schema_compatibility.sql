-- Fix queue runtime for environments where pgmq_public is not enabled.
-- Per Supabase docs, pgmq_public wrappers only exist when Data API exposure is enabled.
-- Canonical backend path should rely on pgmq.*.

CREATE OR REPLACE FUNCTION public.enqueue_calendar_sync_job(
  p_payload jsonb,
  p_sleep_seconds integer DEFAULT 0,
  p_queue_name text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pgmq
AS $$
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
$$;
CREATE OR REPLACE FUNCTION public.pgmq_read_messages(
  p_queue_name text,
  p_vt integer,
  p_qty integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  EXECUTE $q$
    SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
    FROM pgmq.read($1, $2, $3) AS t
  $q$
    INTO v_result
    USING p_queue_name, p_vt, p_qty;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;
CREATE OR REPLACE FUNCTION public.pgmq_delete_message(
  p_queue_name text,
  p_msg_id bigint
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result boolean := false;
BEGIN
  EXECUTE 'SELECT COALESCE(pgmq.delete($1, $2), false)'
    INTO v_result
    USING p_queue_name, p_msg_id;

  RETURN v_result;
END;
$$;
CREATE OR REPLACE FUNCTION public.pgmq_archive_message(
  p_queue_name text,
  p_msg_id bigint
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result boolean := false;
BEGIN
  EXECUTE 'SELECT COALESCE(pgmq.archive($1, $2), false)'
    INTO v_result
    USING p_queue_name, p_msg_id;

  RETURN v_result;
END;
$$;
CREATE OR REPLACE FUNCTION public.pgmq_queue_backlog(
  p_queue_name text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pgmq
AS $$
DECLARE
  v_count bigint := 0;
BEGIN
  BEGIN
    EXECUTE format('SELECT COUNT(*)::bigint FROM pgmq.%I', 'q_' || p_queue_name)
      INTO v_count;
  EXCEPTION
    WHEN undefined_table THEN
      v_count := 0;
  END;

  RETURN COALESCE(v_count, 0);
END;
$$;
NOTIFY pgrst, 'reload schema';
