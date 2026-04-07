-- Migration: Fix Security Definer Views
-- Created at: 2026-02-02 20:31:51
-- Issue: Views were recreated without security_invoker in later migrations
-- Fix: Recreate views with WITH (security_invoker = true)

-- Fix public.calendar_events_full
DROP VIEW IF EXISTS public.calendar_events_full CASCADE;
CREATE OR REPLACE VIEW public.calendar_events_full 
WITH (security_invoker = true) AS
SELECT 
    e.*,
    sd.psychologist_client_id,
    sd.psychologist_service_id,
    sd.session_number,
    sd.clinical_session_id,
    sd.attendance_confirmed,
    sd.billing_status,
    COALESCE(pc.manual_full_name, pc.synced_full_name) as patient_name,
    COALESCE(pc.manual_display_name, pc.synced_display_name) as patient_display_name,
    ps.name as service_name,
    ps.price as service_price,
    ps.duration_minutes as service_duration
FROM public.calendar_events e
LEFT JOIN public.clinical_session_details sd ON sd.calendar_event_id = e.id
LEFT JOIN public.psychologist_clients pc ON pc.id = sd.psychologist_client_id
LEFT JOIN public.psychologist_services ps ON ps.id = sd.psychologist_service_id;
-- Fix public.view_sync_health_stats
DROP VIEW IF EXISTS public.view_sync_health_stats CASCADE;
CREATE OR REPLACE VIEW public.view_sync_health_stats 
WITH (security_invoker = true) AS
SELECT 
    ce.psychologist_id,
    p.full_name as psychologist_name,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'synced') as synced_count,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'error') as error_count,
    MAX(ce.last_synced_at) as last_sync_activity,
    gcc.sync_sessions,
    gcc.updated_at as connection_updated_at
FROM public.calendar_events ce
JOIN public.psychologists p ON ce.psychologist_id = p.id
LEFT JOIN public.google_calendar_connections gcc ON ce.psychologist_id = gcc.psychologist_id
GROUP BY ce.psychologist_id, p.full_name, gcc.sync_sessions, gcc.updated_at;
-- Fix public.view_sync_backlog
DROP VIEW IF EXISTS public.view_sync_backlog CASCADE;
CREATE OR REPLACE VIEW public.view_sync_backlog 
WITH (security_invoker = true) AS
SELECT 
    count(*) as total_backlog,
    count(*) FILTER (WHERE updated_at < now() - interval '1 hour') as stuck_events_1h
FROM public.calendar_events 
WHERE google_sync_status = 'pending';
