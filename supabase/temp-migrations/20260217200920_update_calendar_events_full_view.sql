-- Migration: update_calendar_events_full_view
-- Description: Update calendar_events_full view to use psychologist_patient_id column name

-------------------------------------------------------------------------------
-- 1. DROP AND RECREATE VIEW WITH UPDATED COLUMN NAME
-------------------------------------------------------------------------------

DROP VIEW IF EXISTS public.calendar_events_full;
CREATE OR REPLACE VIEW public.calendar_events_full AS
SELECT 
    e.id,
    e.psychologist_id,
    e.series_id,
    e.event_type,
    e.title,
    e.description,
    e.location,
    e.color,
    e.start_datetime,
    e.end_datetime,
    e.duration_minutes,
    e.timezone,
    e.all_day,
    e.original_start_datetime,
    e.original_end_datetime,
    e.status,
    e.source,
    e.google_event_id,
    e.google_sync_status,
    e.google_sync_error,
    e.last_synced_at,
    e.metadata,
    e.private_notes,
    e.created_at,
    e.updated_at,
    cs.psychologist_patient_id,
    cs.psychologist_service_id,
    cs.session_number,
    cs.id AS clinical_session_id,
    cs.attendance_confirmed,
    cs.billing_status,
    COALESCE(p.manual_full_name, p.synced_full_name) AS patient_name,
    COALESCE(p.manual_display_name, p.synced_display_name) AS patient_display_name,
    ps.name AS service_name,
    ps.price AS service_price,
    ps.duration_minutes AS service_duration
FROM calendar_events e
LEFT JOIN psychologist_clinical_sessions cs ON cs.calendar_event_id = e.id
LEFT JOIN psychologist_patients p ON p.id = cs.psychologist_patient_id
LEFT JOIN psychologist_services ps ON ps.id = cs.psychologist_service_id;
-------------------------------------------------------------------------------
-- 2. TABLE DESCRIPTION
-------------------------------------------------------------------------------

COMMENT ON VIEW public.calendar_events_full IS 'Comprehensive view of calendar events with session, patient, and service details. Updated to use psychologist_patient_id column naming.';
