-- Fix Database Issues Migration
-- This migration fixes several database problems:
-- 1. Creates missing patient_deletion_audit_log table
-- 2. Fixes incorrect table/column checks in migrations
-- 3. Ensures cleanup_expired_patient_deletions function works correctly

-- 1. Create patient_deletion_audit_log table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.patient_deletion_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cleanup_timestamp timestamptz NOT NULL,
  deleted_count integer NOT NULL DEFAULT 0,
  triggered_by text,
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL
);
-- Enable RLS on patient_deletion_audit_log
ALTER TABLE public.patient_deletion_audit_log ENABLE ROW LEVEL SECURITY;
-- Create RLS policy for patient_deletion_audit_log (admin only)
-- Uses is_admin() function which exists in the database
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'patient_deletion_audit_log' 
    AND policyname = 'patient_deletion_audit_log_admin'
  ) THEN
    CREATE POLICY "patient_deletion_audit_log_admin"
    ON public.patient_deletion_audit_log
    FOR SELECT
    TO authenticated
    USING (is_admin());
  END IF;
END $$;
-- 2. Fix cleanup_expired_patient_deletions function to handle missing audit log gracefully
DROP FUNCTION IF EXISTS public.cleanup_expired_patient_deletions() CASCADE;
CREATE OR REPLACE FUNCTION public.cleanup_expired_patient_deletions()
RETURNS TABLE (
  deleted_count integer,
  cleanup_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
-- 3. Fix incorrect index creation checks
-- The original migration had: WHERE tablename = 'IF' which is wrong
-- This should check for 'calendar_events' instead
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE tablename = 'calendar_events' 
    AND schemaname = 'public'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_calendar_events_series_start
    ON public.calendar_events (series_id, start_datetime)
    WHERE series_id IS NOT NULL;
  END IF;
END $$;
-- 4. Fix incorrect table checks for google_sync_idempotency indexes
-- Original had: WHERE tablename = 'if' (lowercase, wrong)
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE tablename = 'google_sync_idempotency' 
    AND schemaname = 'public'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_google_sync_idempotency_psychologist_id 
    ON public.google_sync_idempotency(psychologist_id);
    
    CREATE INDEX IF NOT EXISTS idx_google_sync_idempotency_calendar_event_id 
    ON public.google_sync_idempotency(calendar_event_id);
    
    CREATE INDEX IF NOT EXISTS idx_google_sync_idempotency_status 
    ON public.google_sync_idempotency(status);
    
    CREATE INDEX IF NOT EXISTS idx_google_sync_idempotency_expires_at 
    ON public.google_sync_idempotency(expires_at);
  END IF;
END $$;
-- 5. Add comment to patient_deletion_audit_log table
COMMENT ON TABLE public.patient_deletion_audit_log IS 'Audit log for patient deletion cleanup operations';
