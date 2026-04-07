-- Optimize Google Calendar sync queue topology for pre-launch scale.
-- - Split canonical PGMQ queue by workload class (inbound/outbound/maintenance)
-- - Add inbound webhook coalescing
-- - Replace blanket periodic full resync with sampled maintenance jobs (function-level)
-- - Add worker metrics and richer connection operational fields
-- - Tighten cron fallback cadence to 1 minute

CREATE EXTENSION IF NOT EXISTS pgmq;
-- ============================================================================
-- 1) Queue topology
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_tables
    WHERE schemaname = 'pgmq'
      AND tablename = 'q_gcal_inbound'
  ) THEN
    PERFORM pgmq.create('gcal_inbound');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_tables
    WHERE schemaname = 'pgmq'
      AND tablename = 'q_gcal_outbound'
  ) THEN
    PERFORM pgmq.create('gcal_outbound');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_tables
    WHERE schemaname = 'pgmq'
      AND tablename = 'q_gcal_maintenance'
  ) THEN
    PERFORM pgmq.create('gcal_maintenance');
  END IF;
END;
$$;
CREATE OR REPLACE FUNCTION public.resolve_calendar_sync_queue_name(
  p_payload jsonb,
  p_queue_name text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
-- ============================================================================
-- 2) Inbound coalescing
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.google_sync_inbound_coalesce (
  connection_id uuid PRIMARY KEY REFERENCES public.google_calendar_connections(id) ON DELETE CASCADE,
  msg_id bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_enqueued_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.google_sync_inbound_coalesce ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS google_sync_inbound_coalesce_service_only ON public.google_sync_inbound_coalesce;
CREATE POLICY google_sync_inbound_coalesce_service_only
  ON public.google_sync_inbound_coalesce
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
CREATE OR REPLACE FUNCTION public.release_google_sync_inbound_coalesce(
  p_connection_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.google_sync_inbound_coalesce
  WHERE connection_id = p_connection_id;
END;
$$;
-- Canonical enqueue wrapper used by Edge Functions and app runtime code.
-- Returns NULL when inbound webhook signal was coalesced into an existing pending/processing job.
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

  SELECT pgmq_public.send(
    v_queue_name,
    p_payload,
    GREATEST(COALESCE(p_sleep_seconds, 0), 0)
  ) INTO v_msg_id;

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
-- Queue backlog helper used by health checks.
CREATE OR REPLACE FUNCTION public.get_calendar_sync_queue_backlog()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pgmq
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
-- ============================================================================
-- 3) Connection operational fields
-- ============================================================================

ALTER TABLE public.google_calendar_connections
  ADD COLUMN IF NOT EXISTS watch_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_watch_renewal_at timestamptz,
  ADD COLUMN IF NOT EXISTS sync_token_updated_at timestamptz,
  ADD COLUMN IF NOT EXISTS refresh_error_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_sync_error_code text;
UPDATE public.google_calendar_connections
SET watch_expires_at = watch_expiration
WHERE watch_expiration IS NOT NULL
  AND watch_expires_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_google_calendar_connections_watch_expires_at
  ON public.google_calendar_connections (watch_expires_at)
  WHERE is_connected = true;
-- ============================================================================
-- 4) Worker metrics
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.google_sync_worker_metrics (
  id bigserial PRIMARY KEY,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  worker_id text,
  queue_name text NOT NULL,
  batch_size integer NOT NULL DEFAULT 0,
  successful integer NOT NULL DEFAULT 0,
  failed integer NOT NULL DEFAULT 0,
  skipped integer NOT NULL DEFAULT 0,
  requeued integer NOT NULL DEFAULT 0,
  duration_ms integer NOT NULL DEFAULT 0,
  backlog_after bigint,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
ALTER TABLE public.google_sync_worker_metrics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS google_sync_worker_metrics_service_only ON public.google_sync_worker_metrics;
CREATE POLICY google_sync_worker_metrics_service_only
  ON public.google_sync_worker_metrics
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
CREATE INDEX IF NOT EXISTS idx_google_sync_worker_metrics_recorded_at
  ON public.google_sync_worker_metrics (recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_google_sync_worker_metrics_queue_name
  ON public.google_sync_worker_metrics (queue_name, recorded_at DESC);
-- ============================================================================
-- 5) Scheduler updates
-- ============================================================================

DO $$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid
    FROM cron.job
    WHERE jobname = 'trigger-process-sync-queue'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
END;
$$;
SELECT cron.schedule(
  'trigger-process-sync-queue',
  '* * * * *',
  $$SELECT net.http_post(
      url := 'https://ecilqoemhxilnddugrql.supabase.co/functions/v1/trigger-process-sync-queue',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)),
      body := '{}'
  );$$
);
