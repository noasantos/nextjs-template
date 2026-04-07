-- Advisor Warnings and Suggestions Fixes

-- 1. Security (INFO): RLS Enabled No Policy
-- Tables with RLS enabled but no policies

-- public.psychologist_client_services
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_client_services' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage client services" ON public.psychologist_client_services;
        CREATE POLICY "Psychologists can manage client services" ON public.psychologist_client_services
          FOR ALL TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
    END IF;
END $$;
-- public.psychologist_clients
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_clients' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage their clients" ON public.psychologist_clients;
        CREATE POLICY "Psychologists can manage their clients" ON public.psychologist_clients
          FOR ALL TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
          
        DROP POLICY IF EXISTS "Patients can view their own client record" ON public.psychologist_clients;
        CREATE POLICY "Patients can view their own client record" ON public.psychologist_clients
          FOR SELECT TO authenticated USING ((SELECT auth.uid()) = patient_id);
    END IF;
END $$;
-- public.user_roles
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_roles' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Users can view own roles" ON public.user_roles;
        CREATE POLICY "Users can view own roles" ON public.user_roles
          FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
          
        DROP POLICY IF EXISTS "Admins can manage user roles" ON public.user_roles;
        CREATE POLICY "Admins can manage user roles" ON public.user_roles
          FOR ALL TO authenticated USING (is_admin());
    END IF;
END $$;
-- 2. Performance (WARN): Auth RLS Initialization Plan
-- Replacing auth.role() with (select auth.role())

-- public.psychologist_invoices
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_invoices' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_invoices_service_role" ON public.psychologist_invoices;
        CREATE POLICY "psychologist_invoices_service_role" ON public.psychologist_invoices
          FOR ALL TO public 
          USING ((SELECT auth.role()) = 'service_role')
          WITH CHECK ((SELECT auth.role()) = 'service_role');
    END IF;
END $$;
-- 3. Performance (WARN): Multiple Permissive Policies Consolidation
-- Removing redundant specific action policies when a broad 'ALL' policy already covers them.

-- linktree_links
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'linktree_links' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "linktree_links_select_public_or_own" ON public.linktree_links;
    END IF;
END $$;
-- (linktree_links_owner_access already exists and covers psychologist_id = auth.uid())

-- psychologist_availability
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_availability' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_availability_select_own" ON public.psychologist_availability;
    END IF;
END $$;
-- (psychologist_availability_owner_access already exists)

-- psychologist_locations
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_locations_delete_own" ON public.psychologist_locations;
        DROP POLICY IF EXISTS "psychologist_locations_insert_own" ON public.psychologist_locations;
        DROP POLICY IF EXISTS "psychologist_locations_select_own" ON public.psychologist_locations;
        DROP POLICY IF EXISTS "psychologist_locations_update_own" ON public.psychologist_locations;
    END IF;
END $$;
-- (psychologist_locations_owner_access already exists)

-- session_reschedule_requests
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'session_reschedule_requests' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "reschedule_requests_select" ON public.session_reschedule_requests;
    END IF;
END $$;
-- (reschedule_requests_owner_access already exists for psychologist. Need to add patient select back if needed, but the broad one handles it better)
-- Re-adding a clean select for patients and psychologists
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'session_reschedule_requests' AND schemaname = 'public') THEN
        CREATE POLICY "reschedule_requests_select_v2" ON public.session_reschedule_requests
        FOR SELECT TO authenticated USING (
            is_admin() OR 
            EXISTS (
                SELECT 1 FROM public.clinical_sessions s 
                WHERE s.id = session_id AND (
                    s.psychologist_id = (SELECT auth.uid()) OR 
                    EXISTS (
                        SELECT 1 FROM public.psychologist_clients pc 
                        WHERE pc.id = s.psychologist_client_id AND pc.patient_id = (SELECT auth.uid())
                    )
                )
            )
        );
    END IF;
END $$;
-- 4. Performance (INFO): Unindexed Foreign Keys (Public Schema)

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_emergency_contacts' AND schemaname = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_patient_emergency_contacts_created_by ON public.patient_emergency_contacts(created_by);
        CREATE INDEX IF NOT EXISTS idx_patient_emergency_contacts_psychologist_client_id ON public.patient_emergency_contacts(psychologist_client_id);
        CREATE INDEX IF NOT EXISTS idx_patient_emergency_contacts_updated_by ON public.patient_emergency_contacts(updated_by);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_timeline_events' AND schemaname = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_patient_timeline_events_created_by ON public.patient_timeline_events(created_by);
        CREATE INDEX IF NOT EXISTS idx_patient_timeline_events_psychologist_client_id ON public.patient_timeline_events(psychologist_client_id);
        CREATE INDEX IF NOT EXISTS idx_patient_timeline_events_psychologist_id ON public.patient_timeline_events(psychologist_id);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_client_services' AND schemaname = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_client_services_psychologist_id ON public.psychologist_client_services(psychologist_id);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_invoices' AND schemaname = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_invoices_psychologist_id ON public.psychologist_invoices(psychologist_id);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_patient_guardian_documents' AND schemaname = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psych_patient_guard_doc_guardian_id ON public.psychologist_patient_guardian_documents(guardian_id);
        CREATE INDEX IF NOT EXISTS idx_psych_patient_guard_doc_patient_id ON public.psychologist_patient_guardian_documents(patient_id);
        CREATE INDEX IF NOT EXISTS idx_psych_patient_guard_doc_psychologist_id ON public.psychologist_patient_guardian_documents(psychologist_id);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_patient_guardians' AND schemaname = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_patient_guardians_patient_id ON public.psychologist_patient_guardians(patient_id);
        CREATE INDEX IF NOT EXISTS idx_psychologist_patient_guardians_psychologist_id ON public.psychologist_patient_guardians(psychologist_id);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_patient_medical_items' AND schemaname = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psych_patient_med_items_psychologist_id ON public.psychologist_patient_medical_items(psychologist_id);
        CREATE INDEX IF NOT EXISTS idx_psych_patient_med_items_therapist_client_id ON public.psychologist_patient_medical_items(therapist_client_id);
    END IF;
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_services' AND schemaname = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_services_psychologist_id ON public.psychologist_services(psychologist_id);
    END IF;
END $$;
