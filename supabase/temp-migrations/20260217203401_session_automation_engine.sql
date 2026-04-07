-- Migration: session_automation_engine
-- Description: Implement automation engine for billing, reminders, and confirmations

-------------------------------------------------------------------------------
-- 1. FUNCTION: Process pending billing for sessions
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.process_pending_session_billing(
  p_batch_size INTEGER DEFAULT 100
)
RETURNS TABLE (
  processed_count INTEGER,
  success_count INTEGER,
  error_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_processed INTEGER := 0;
  v_success INTEGER := 0;
  v_errors INTEGER := 0;
  v_session RECORD;
BEGIN
  -- Process sessions with pending billing that are due for retry
  FOR v_session IN
    SELECT 
      pcs.id as session_id,
      pcs.psychologist_id,
      pcs.billing_status,
      pcs.billing_next_attempt_at,
      pcs.charge_id,
      pc.price_cents,
      pc.description,
      pcs.automation_metadata
    FROM public.psychologist_clinical_sessions pcs
    LEFT JOIN public.psychologist_patient_charges pc ON pc.id = pcs.charge_id
    WHERE pcs.billing_status IN ('pending', 'failed')
      AND (pcs.billing_next_attempt_at IS NULL OR pcs.billing_next_attempt_at <= NOW())
      AND pcs.billing_attempt_count < 3
    ORDER BY pcs.billing_next_attempt_at ASC
    LIMIT p_batch_size
  LOOP
    v_processed := v_processed + 1;
    
    BEGIN
      -- Update attempt count and next attempt time (exponential backoff)
      UPDATE public.psychologist_clinical_sessions
      SET 
        billing_attempt_count = COALESCE(billing_attempt_count, 0) + 1,
        billing_next_attempt_at = CASE 
          WHEN billing_attempt_count >= 2 THEN NULL -- Stop retrying after 3 attempts
          ELSE NOW() + (INTERVAL '1 hour' * POWER(2, COALESCE(billing_attempt_count, 0)))
        END,
        automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
          'last_billing_attempt', NOW(),
          'billing_attempt_' || COALESCE(billing_attempt_count, 0) + 1, jsonb_build_object(
            'status', 'processing',
            'timestamp', NOW()
          )
        )
      WHERE id = v_session.session_id;
      
      v_success := v_success + 1;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      
      -- Log error in session metadata
      UPDATE public.psychologist_clinical_sessions
      SET 
        billing_last_error = SQLERRM,
        automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
          'last_billing_error', jsonb_build_object(
            'message', SQLERRM,
            'timestamp', NOW()
          )
        )
      WHERE id = v_session.session_id;
    END;
  END LOOP;
  
  RETURN QUERY SELECT v_processed, v_success, v_errors;
END;
$$;
COMMENT ON FUNCTION public.process_pending_session_billing(INTEGER) IS 'Processes billing for sessions with pending or failed billing status. Uses exponential backoff for retries.';
-------------------------------------------------------------------------------
-- 2. FUNCTION: Get sessions needing reminders
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_sessions_needing_reminders(
  p_reminder_type TEXT,
  p_batch_size INTEGER DEFAULT 100
)
RETURNS TABLE (
  session_id UUID,
  psychologist_id UUID,
  patient_id UUID,
  session_start_time TIMESTAMP WITH TIME ZONE,
  patient_phone TEXT,
  patient_email TEXT,
  reminder_hours_before INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hours_before INTEGER;
BEGIN
  -- Define hours before based on reminder type
  v_hours_before := CASE p_reminder_type
    WHEN '24h_before' THEN 24
    WHEN '1h_before' THEN 1
    ELSE 24
  END;
  
  RETURN QUERY
  SELECT 
    pcs.id as session_id,
    pcs.psychologist_id,
    pcs.psychologist_patient_id as patient_id,
    pcs.start_time as session_start_time,
    pp.manual_phone as patient_phone,
    pp.manual_email as patient_email,
    v_hours_before as reminder_hours_before
  FROM public.psychologist_clinical_sessions pcs
  JOIN public.psychologist_patients pp ON pp.id = pcs.psychologist_patient_id
  WHERE pcs.start_time BETWEEN NOW() + INTERVAL '1 minute' AND NOW() + (v_hours_before || ' hours')::INTERVAL
    AND pcs.attendance_confirmed IS NULL
    AND (
      -- Check if this reminder type has already been sent
      pcs.automation_metadata IS NULL
      OR NOT (pcs.automation_metadata ? p_reminder_type)
      OR (pcs.automation_metadata->p_reminder_type->>'sent_at') IS NULL
    )
  ORDER BY pcs.start_time ASC
  LIMIT p_batch_size;
END;
$$;
COMMENT ON FUNCTION public.get_sessions_needing_reminders(TEXT, INTEGER) IS 'Returns sessions that need reminders sent (24h_before, 1h_before, etc.)';
-------------------------------------------------------------------------------
-- 3. FUNCTION: Mark reminder as sent
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_reminder_sent(
  p_session_id UUID,
  p_reminder_type TEXT,
  p_channel TEXT -- 'whatsapp', 'email', 'sms'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.psychologist_clinical_sessions
  SET 
    automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
      p_reminder_type, jsonb_build_object(
        'sent_at', NOW(),
        'channel', p_channel,
        'status', 'sent'
      )
    ),
    reminder_sent_at = CASE 
      WHEN p_reminder_type = '24h_before' THEN NOW()
      ELSE reminder_sent_at
    END
  WHERE id = p_session_id;
  
  RETURN FOUND;
END;
$$;
COMMENT ON FUNCTION public.mark_reminder_sent(UUID, TEXT, TEXT) IS 'Marks a reminder as sent in the session automation_metadata';
-------------------------------------------------------------------------------
-- 4. FUNCTION: Update attendance confirmation
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.update_attendance_confirmation(
  p_session_id UUID,
  p_confirmed BOOLEAN,
  p_confirmation_source TEXT, -- 'patient_whatsapp', 'patient_email', 'psychologist_manual'
  p_confirmed_by UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.psychologist_clinical_sessions
  SET 
    attendance_confirmed = p_confirmed,
    confirmation_sent_at = NOW(),
    automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
      'attendance_confirmation', jsonb_build_object(
        'confirmed', p_confirmed,
        'confirmed_at', NOW(),
        'source', p_confirmation_source,
        'confirmed_by', p_confirmed_by
      )
    )
  WHERE id = p_session_id;
  
  RETURN FOUND;
END;
$$;
COMMENT ON FUNCTION public.update_attendance_confirmation(UUID, BOOLEAN, TEXT, UUID) IS 'Updates attendance confirmation with source tracking';
-------------------------------------------------------------------------------
-- 5. FUNCTION: Sync calendar event to session
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_calendar_event_to_session(
  p_event_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event RECORD;
  v_session_id UUID;
BEGIN
  -- Get calendar event details
  SELECT 
    ce.id,
    ce.start_datetime,
    ce.end_datetime,
    ce.psychologist_id,
    pcs.id as existing_session_id
  INTO v_event
  FROM public.calendar_events ce
  LEFT JOIN public.psychologist_clinical_sessions pcs ON pcs.calendar_event_id = ce.id
  WHERE ce.id = p_event_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Update existing session or nothing to do
  IF v_event.existing_session_id IS NOT NULL THEN
    UPDATE public.psychologist_clinical_sessions
    SET 
      start_time = v_event.start_datetime,
      end_time = v_event.end_datetime,
      updated_at = NOW()
    WHERE id = v_event.existing_session_id;
    
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$;
COMMENT ON FUNCTION public.sync_calendar_event_to_session(UUID) IS 'Syncs a calendar event time to its associated clinical session';
-------------------------------------------------------------------------------
-- 6. TRIGGER: Auto-sync calendar changes to sessions
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.tr_sync_calendar_to_session()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only sync if this is a session event and times changed
  IF NEW.event_type = 'session' AND (
    OLD.start_datetime IS DISTINCT FROM NEW.start_datetime
    OR OLD.end_datetime IS DISTINCT FROM NEW.end_datetime
  ) THEN
    UPDATE public.psychologist_clinical_sessions
    SET 
      start_time = NEW.start_datetime,
      end_time = NEW.end_datetime,
      updated_at = NOW()
    WHERE calendar_event_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.tr_sync_calendar_to_session() IS 'Automatically syncs calendar event changes to clinical sessions';
-- Create the trigger
DROP TRIGGER IF EXISTS trg_sync_calendar_to_session ON public.calendar_events;
CREATE TRIGGER trg_sync_calendar_to_session
  AFTER UPDATE ON public.calendar_events
  FOR EACH ROW
  WHEN (OLD.start_datetime IS DISTINCT FROM NEW.start_datetime OR OLD.end_datetime IS DISTINCT FROM NEW.end_datetime)
  EXECUTE FUNCTION public.tr_sync_calendar_to_session();
-------------------------------------------------------------------------------
-- 7. TABLE DESCRIPTIONS
-------------------------------------------------------------------------------

COMMENT ON COLUMN public.psychologist_clinical_sessions.billing_status IS 'Current billing status: pending, processing, completed, failed';
COMMENT ON COLUMN public.psychologist_clinical_sessions.billing_next_attempt_at IS 'When to next attempt billing (for failed payments)';
COMMENT ON COLUMN public.psychologist_clinical_sessions.billing_attempt_count IS 'Number of billing attempts made';
COMMENT ON COLUMN public.psychologist_clinical_sessions.automation_metadata IS 'JSONB tracking reminders, confirmations, and automation state';
COMMENT ON COLUMN public.psychologist_clinical_sessions.attendance_confirmed IS 'Whether patient confirmed attendance';
COMMENT ON COLUMN public.psychologist_clinical_sessions.confirmation_sent_at IS 'When confirmation was last sent/received';
COMMENT ON COLUMN public.psychologist_clinical_sessions.reminder_sent_at IS 'When 24h reminder was sent';
