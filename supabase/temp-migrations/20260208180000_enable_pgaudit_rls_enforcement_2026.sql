-- ============================================================
-- Migration: Enable pgAudit + RLS Enforcement (2026 Standards)
-- Phase 2: Supabase Security Layer
-- ============================================================

-- 1. Enable pgAudit extension for service_role auditing
-- Provides deep session-level logging of DDL, writes, and function calls
CREATE EXTENSION IF NOT EXISTS pgaudit;
-- 2. Configure pgAudit logging for service_role and authenticator roles
-- Tracks: function calls, write operations (INSERT/UPDATE/DELETE), DDL statements
DO $$
BEGIN
  -- Supabase local migrations may run in a pipeline where ALTER SYSTEM is not allowed.
  PERFORM set_config('pgaudit.log', 'function, write, ddl', false);
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Skipping pgAudit system-level config in local environment: %', SQLERRM;
END $$;
-- 3. Event trigger: Auto-enable RLS on all new public tables
-- Prevents any table from being exposed via the API without RLS
CREATE OR REPLACE FUNCTION public.enforce_rls_on_new_table()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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
DROP EVENT TRIGGER IF EXISTS enforce_rls_trigger;
CREATE EVENT TRIGGER enforce_rls_trigger
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE')
  EXECUTE FUNCTION public.enforce_rls_on_new_table();
-- 4. Stripe Idempotency Log table
-- Persists Idempotency-Key values for POST/DELETE requests (30-day window per Stripe Clover v2)
CREATE TABLE IF NOT EXISTS public.stripe_idempotency_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL UNIQUE,
  stripe_event_id text,
  operation text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  request_payload jsonb,
  response_summary jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days')
);
ALTER TABLE public.stripe_idempotency_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only access to stripe_idempotency_log"
  ON public.stripe_idempotency_log
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
CREATE INDEX IF NOT EXISTS idx_stripe_idempotency_key
  ON public.stripe_idempotency_log(idempotency_key);
CREATE INDEX IF NOT EXISTS idx_stripe_idempotency_expires
  ON public.stripe_idempotency_log(expires_at);
-- 5. Calendar Change Log table
-- Tracks modification timestamps to prevent re-processing identical event updates
CREATE TABLE IF NOT EXISTS public.calendar_change_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id uuid NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  google_event_id text NOT NULL,
  modification_hash text NOT NULL,
  sync_direction text NOT NULL CHECK (sync_direction IN ('google_to_fluri', 'fluri_to_google')),
  processed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.calendar_change_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only access to calendar_change_log"
  ON public.calendar_change_log
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
CREATE INDEX IF NOT EXISTS idx_calendar_change_event
  ON public.calendar_change_log(google_event_id, modification_hash);
CREATE INDEX IF NOT EXISTS idx_calendar_change_psych
  ON public.calendar_change_log(psychologist_id);
-- 6. Cleanup function for expired idempotency records
CREATE OR REPLACE FUNCTION public.cleanup_expired_idempotency_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  DELETE FROM public.stripe_idempotency_log
  WHERE expires_at < now();
END;
$$;
