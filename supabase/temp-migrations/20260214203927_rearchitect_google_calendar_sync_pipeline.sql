-- Re-architect Google Calendar sync to a single queue-driven execution path.
-- Canonical queue backend: PGMQ (calendar_sync_queue).

-- ============================================================================
-- 1) Schema extensions (calendar + connection state)
-- ============================================================================

ALTER TABLE public.calendar_events
  ADD COLUMN IF NOT EXISTS google_recurring_event_id text,
  ADD COLUMN IF NOT EXISTS google_original_start_time timestamptz,
  ADD COLUMN IF NOT EXISTS sync_origin text NOT NULL DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS remote_updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS remote_etag text;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'calendar_events_sync_origin_check'
      AND conrelid = 'public.calendar_events'::regclass
  ) THEN
    ALTER TABLE public.calendar_events
      ADD CONSTRAINT calendar_events_sync_origin_check
      CHECK (sync_origin IN ('user', 'google', 'system'));
  END IF;
END;
$$;
ALTER TABLE public.google_calendar_connections
  ADD COLUMN IF NOT EXISTS sync_state text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS last_successful_sync_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_webhook_at timestamptz;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'google_calendar_connections_sync_state_check'
      AND conrelid = 'public.google_calendar_connections'::regclass
  ) THEN
    ALTER TABLE public.google_calendar_connections
      ADD CONSTRAINT google_calendar_connections_sync_state_check
      CHECK (sync_state IN ('active', 'needs_reauth', 'disabled', 'needs_full_resync'));
  END IF;
END;
$$;
-- ============================================================================
-- 2) Queue backend: PGMQ
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgmq;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_tables
    WHERE schemaname = 'pgmq'
      AND tablename = 'q_calendar_sync_queue'
  ) THEN
    PERFORM pgmq.create('calendar_sync_queue');
  END IF;
END;
$$;
-- Canonical enqueue wrapper used by Edge Functions and app runtime code.
CREATE OR REPLACE FUNCTION public.enqueue_calendar_sync_job(
  p_payload jsonb,
  p_sleep_seconds integer DEFAULT 0
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pgmq
AS $$
DECLARE
  v_msg_id bigint;
BEGIN
  SELECT pgmq_public.send(
    'calendar_sync_queue',
    p_payload,
    GREATEST(COALESCE(p_sleep_seconds, 0), 0)
  ) INTO v_msg_id;

  RETURN v_msg_id;
END;
$$;
-- Optional health helper for queue backlog checks.
CREATE OR REPLACE FUNCTION public.get_calendar_sync_queue_backlog()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pgmq
AS $$
DECLARE
  v_count bigint;
BEGIN
  BEGIN
    EXECUTE 'SELECT COUNT(*)::bigint FROM pgmq.q_calendar_sync_queue' INTO v_count;
    RETURN COALESCE(v_count, 0);
  EXCEPTION
    WHEN undefined_table THEN
      RETURN 0;
  END;
END;
$$;
-- ============================================================================
-- 3) Idempotency + indexes
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.google_sync_job_dedup (
  idempotency_key text PRIMARY KEY,
  processed_at timestamptz NOT NULL DEFAULT now(),
  outcome jsonb
);
ALTER TABLE public.google_sync_job_dedup ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS google_sync_job_dedup_service_only ON public.google_sync_job_dedup;
CREATE POLICY google_sync_job_dedup_service_only
  ON public.google_sync_job_dedup
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
CREATE UNIQUE INDEX IF NOT EXISTS uniq_calendar_events_google_event_id
  ON public.calendar_events(psychologist_id, google_event_id)
  WHERE google_event_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uniq_calendar_events_google_recurring_instance
  ON public.calendar_events(psychologist_id, google_recurring_event_id, google_original_start_time)
  WHERE google_recurring_event_id IS NOT NULL
    AND google_original_start_time IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_calendar_events_google_recurring_lookup
  ON public.calendar_events(psychologist_id, google_recurring_event_id, google_original_start_time);
-- ============================================================================
-- 4) Origin stamping + outbound trigger (INSERT/UPDATE/DELETE)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.stamp_calendar_event_sync_origin()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  IF auth.role() IS NOT NULL AND auth.role() <> 'service_role' THEN
    NEW.sync_origin := 'user';
  END IF;

  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_stamp_calendar_event_sync_origin ON public.calendar_events;
CREATE TRIGGER trg_stamp_calendar_event_sync_origin
  BEFORE INSERT OR UPDATE ON public.calendar_events
  FOR EACH ROW
  EXECUTE FUNCTION public.stamp_calendar_event_sync_origin();
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
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.sync_origin <> 'user' THEN
      RETURN NEW;
    END IF;
    v_action := 'create';
    v_event_id := NEW.id;
    v_psychologist_id := NEW.psychologist_id;
    v_google_event_id := NEW.google_event_id;
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
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.sync_origin <> 'user' THEN
      RETURN OLD;
    END IF;
    v_action := 'delete';
    v_event_id := OLD.id;
    v_psychologist_id := OLD.psychologist_id;
    v_google_event_id := OLD.google_event_id;
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
      'reason', 'calendar_event_' || lower(TG_OP)
    )
  );

  PERFORM public.enqueue_calendar_sync_job(v_payload, 0);

  RETURN COALESCE(NEW, OLD);
END;
$$;
DROP TRIGGER IF EXISTS trigger_enqueue_google_sync ON public.calendar_events;
CREATE TRIGGER trigger_enqueue_google_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.calendar_events
  FOR EACH ROW
  EXECUTE FUNCTION public.enqueue_event_for_google_sync_v3();
-- Cleanup obsolete claim RPC from sync_queue approach (if present).
DROP FUNCTION IF EXISTS public.claim_sync_jobs(integer, text);
