-- Critical Security Advisor Fixes

-- 1. Enable RLS on tables where it was missing or disabled
DO $$ BEGIN
    -- psychologist_invoices
    ALTER TABLE IF EXISTS public.psychologist_invoices ENABLE ROW LEVEL SECURITY;
    
    -- psychologist_patient_guardians
    ALTER TABLE IF EXISTS public.psychologist_patient_guardians ENABLE ROW LEVEL SECURITY;
    
    -- psychologist_patient_guardian_documents
    ALTER TABLE IF EXISTS public.psychologist_patient_guardian_documents ENABLE ROW LEVEL SECURITY;
    
    -- patient_emergency_contacts
    ALTER TABLE IF EXISTS public.patient_emergency_contacts ENABLE ROW LEVEL SECURITY;
    
    -- psychologist_patient_medical_items
    ALTER TABLE IF EXISTS public.psychologist_patient_medical_items ENABLE ROW LEVEL SECURITY;
    
    -- patient_timeline_events
    ALTER TABLE IF EXISTS public.patient_timeline_events ENABLE ROW LEVEL SECURITY;
END $$;
-- 2. Add basic policies for these tables (Owner access)
-- Note: psychologist_invoices already has policies, but we ensure they are clean.

-- psychologist_patient_guardians
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_patient_guardians' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage patient guardians" ON public.psychologist_patient_guardians;
        CREATE POLICY "Psychologists can manage patient guardians" ON public.psychologist_patient_guardians
          FOR ALL TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
    END IF;
END $$;
-- psychologist_patient_guardian_documents
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_patient_guardian_documents' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage patient guardian documents" ON public.psychologist_patient_guardian_documents;
        CREATE POLICY "Psychologists can manage patient guardian documents" ON public.psychologist_patient_guardian_documents
          FOR ALL TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
    END IF;
END $$;
-- patient_emergency_contacts
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_emergency_contacts' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage patient emergency contacts" ON public.patient_emergency_contacts;
        CREATE POLICY "Psychologists can manage patient emergency contacts" ON public.patient_emergency_contacts
          FOR ALL TO authenticated USING (
            EXISTS (
              SELECT 1 FROM public.psychologist_clients pc 
              WHERE pc.id = psychologist_client_id AND pc.psychologist_id = (SELECT auth.uid())
            )
          );
    END IF;
END $$;
-- psychologist_patient_medical_items
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_patient_medical_items' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage patient medical items" ON public.psychologist_patient_medical_items;
        CREATE POLICY "Psychologists can manage patient medical items" ON public.psychologist_patient_medical_items
          FOR ALL TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
    END IF;
END $$;
-- patient_timeline_events
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_timeline_events' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage patient timeline events" ON public.patient_timeline_events;
        CREATE POLICY "Psychologists can manage patient timeline events" ON public.patient_timeline_events
          FOR ALL TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
    END IF;
END $$;
-- 3. Fix Security Definer Views (Recreate as Security Invoker)

-- public.calendar_events_full
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
-- public.view_sync_health_stats
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
    MAX(ce.last_synced_at) as last_sync_activity
FROM public.calendar_events ce
JOIN public.psychologists p ON ce.psychologist_id = p.id
GROUP BY ce.psychologist_id, p.full_name;
-- public.view_sync_backlog
DROP VIEW IF EXISTS public.view_sync_backlog CASCADE;
CREATE OR REPLACE VIEW public.view_sync_backlog 
WITH (security_invoker = true) AS
SELECT 
    count(*) as total_backlog,
    count(*) FILTER (WHERE updated_at < now() - interval '1 hour') as stuck_events_1h
FROM public.calendar_events 
WHERE google_sync_status = 'pending';
-- Restore grants for views
GRANT SELECT ON public.calendar_events_full TO authenticated;
GRANT SELECT ON public.calendar_events_full TO anon;
GRANT SELECT ON public.view_sync_health_stats TO authenticated;
GRANT SELECT ON public.view_sync_backlog TO authenticated;
