-- Performance Advisor Fixes: RLS Optimization and Redundancy Removal

-- Helper function to drop policies safely
DO $$ 
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND (
            policyname IN (
                'Psychologists can view own connection', 'Psychologists can insert own connection', 
                'Psychologists can update own connection', 'Psychologists can delete own connection',
                'Psychologists can view own series', 'Psychologists can insert own series', 
                'Psychologists can update own series', 'Psychologists can delete own series',
                'Psychologists can view own events', 'Psychologists can insert own events', 
                'Psychologists can update own events', 'Psychologists can delete own events',
                'Psychologists can manage exceptions via series', 'Psychologists can view own sync logs',
                'Users can view their own conflicts', 'Users can update their own conflicts',
                'psychologist_onboarding_state_select_own', 'psychologist_onboarding_state_insert_own', 
                'psychologist_onboarding_state_update_own', 'psychologist_profiles_select',
                'psychologist_profiles_select_public', 'psychologist_profiles_select_own',
                'psychologist_profiles_insert', 'psychologist_profiles_update',
                'psychologist_services_select', 'psychologist_services_delete', 
                'psychologist_services_insert', 'psychologist_services_update',
                'specialties_catalog_select_anon', 'specialties_catalog_select_authenticated',
                'Psychologists can insert their own record', 'Psychologists can update their own record',
                'google_sync_idempotency_insert_own', 'google_sync_idempotency_select_own', 'google_sync_idempotency_update_own',
                'google_sync_queue_insert_own', 'google_sync_queue_select_own', 'google_sync_queue_update_own',
                'weekly_availability_insert_own', 'weekly_availability_select_own', 'weekly_availability_update_own'
            )
            OR (tablename = 'psychologist_profiles' AND policyname = 'psychologist_profiles_select')
            OR (tablename = 'psychologist_services' AND policyname = 'psychologist_services_select')
        )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
    END LOOP;
END $$;
-- 1. Optimized and Consolidated Policies for Authenticated Users (is_admin() or own record)
-- These use (SELECT auth.uid()) to avoid re-evaluation for each row.

-- google_calendar_connections
DROP POLICY IF EXISTS "google_calendar_connections_owner_access" ON public.google_calendar_connections;
CREATE POLICY "google_calendar_connections_owner_access" ON public.google_calendar_connections
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- calendar_event_series
DROP POLICY IF EXISTS "calendar_event_series_owner_access" ON public.calendar_event_series;
CREATE POLICY "calendar_event_series_owner_access" ON public.calendar_event_series
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- calendar_events
DROP POLICY IF EXISTS "calendar_events_owner_access" ON public.calendar_events;
CREATE POLICY "calendar_events_owner_access" ON public.calendar_events
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- calendar_event_series_exceptions
DROP POLICY IF EXISTS "series_exceptions_owner_access" ON public.calendar_event_series_exceptions;
CREATE POLICY "series_exceptions_owner_access" ON public.calendar_event_series_exceptions
FOR ALL TO authenticated USING (is_admin() OR EXISTS (
    SELECT 1 FROM public.calendar_event_series s 
    WHERE s.id = series_id AND s.psychologist_id = (SELECT auth.uid())
));
-- google_sync_logs
DROP POLICY IF EXISTS "google_sync_logs_owner_access" ON public.google_sync_logs;
CREATE POLICY "google_sync_logs_owner_access" ON public.google_sync_logs
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- google_sync_idempotency
DROP POLICY IF EXISTS "google_sync_idempotency_owner_access" ON public.google_sync_idempotency;
CREATE POLICY "google_sync_idempotency_owner_access" ON public.google_sync_idempotency
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- google_sync_queue
DROP POLICY IF EXISTS "google_sync_queue_owner_access" ON public.google_sync_queue;
CREATE POLICY "google_sync_queue_owner_access" ON public.google_sync_queue
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- psychologist_availability
DROP POLICY IF EXISTS "psychologist_availability_owner_access" ON public.psychologist_availability;
CREATE POLICY "psychologist_availability_owner_access" ON public.psychologist_availability
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- psychologist_locations
DROP POLICY IF EXISTS "psychologist_locations_owner_access" ON public.psychologist_locations;
CREATE POLICY "psychologist_locations_owner_access" ON public.psychologist_locations
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- sync_conflict_resolutions
DROP POLICY IF EXISTS "sync_conflict_resolutions_owner_access" ON public.sync_conflict_resolutions;
CREATE POLICY "sync_conflict_resolutions_owner_access" ON public.sync_conflict_resolutions
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- weekly_availability_configs
DROP POLICY IF EXISTS "weekly_availability_configs_owner_access" ON public.weekly_availability_configs;
CREATE POLICY "weekly_availability_configs_owner_access" ON public.weekly_availability_configs
FOR ALL TO authenticated USING (is_admin() OR (SELECT auth.uid()) = user_id);
-- session_reschedule_requests
DROP POLICY IF EXISTS "reschedule_requests_owner_access" ON public.session_reschedule_requests;
CREATE POLICY "reschedule_requests_owner_access" ON public.session_reschedule_requests
FOR ALL TO authenticated USING (
    is_admin() OR 
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s 
        WHERE s.id = session_id AND s.psychologist_id = (SELECT auth.uid())
    )
);
-- 2. psychologist_onboarding_state (Optimized)
DROP POLICY IF EXISTS "psychologist_onboarding_state_select_own" ON public.psychologist_onboarding_state;
CREATE POLICY "psychologist_onboarding_state_select_own" ON public.psychologist_onboarding_state
FOR SELECT TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
DROP POLICY IF EXISTS "psychologist_onboarding_state_insert_own" ON public.psychologist_onboarding_state;
CREATE POLICY "psychologist_onboarding_state_insert_own" ON public.psychologist_onboarding_state
FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = psychologist_id);
DROP POLICY IF EXISTS "psychologist_onboarding_state_update_own" ON public.psychologist_onboarding_state;
CREATE POLICY "psychologist_onboarding_state_update_own" ON public.psychologist_onboarding_state
FOR UPDATE TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
-- 3. Consolidated psychologist_profiles
DROP POLICY IF EXISTS "psychologist_profiles_select_public_or_own" ON public.psychologist_profiles;
CREATE POLICY "psychologist_profiles_select_public_or_own" ON public.psychologist_profiles
FOR SELECT TO public USING (
    ((is_public = true) AND (display_name IS NOT NULL)) OR ((SELECT auth.uid()) = id)
);
DROP POLICY IF EXISTS "psychologist_profiles_insert_own" ON public.psychologist_profiles;
CREATE POLICY "psychologist_profiles_insert_own" ON public.psychologist_profiles
FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = id);
DROP POLICY IF EXISTS "psychologist_profiles_update_own" ON public.psychologist_profiles;
CREATE POLICY "psychologist_profiles_update_own" ON public.psychologist_profiles
FOR UPDATE TO authenticated USING ((SELECT auth.uid()) = id);
-- 4. Consolidated psychologist_services
DROP POLICY IF EXISTS "psychologist_services_select_anon" ON public.psychologist_services;
CREATE POLICY "psychologist_services_select_anon" ON public.psychologist_services
FOR SELECT TO anon USING (
    (is_active = true) AND (EXISTS (
        SELECT 1 FROM public.psychologist_profiles pp 
        WHERE pp.id = psychologist_id AND pp.is_public = true
    ))
);
DROP POLICY IF EXISTS "psychologist_services_select_authenticated" ON public.psychologist_services;
CREATE POLICY "psychologist_services_select_authenticated" ON public.psychologist_services
FOR SELECT TO authenticated USING (
    ((SELECT auth.uid()) = psychologist_id) OR 
    ((is_active = true) AND (EXISTS (
        SELECT 1 FROM public.psychologist_profiles pp 
        WHERE pp.id = psychologist_id AND pp.is_public = true
    )))
);
DROP POLICY IF EXISTS "psychologist_services_insert_own" ON public.psychologist_services;
CREATE POLICY "psychologist_services_insert_own" ON public.psychologist_services
FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = psychologist_id);
DROP POLICY IF EXISTS "psychologist_services_update_own" ON public.psychologist_services;
CREATE POLICY "psychologist_services_update_own" ON public.psychologist_services
FOR UPDATE TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
DROP POLICY IF EXISTS "psychologist_services_delete_own" ON public.psychologist_services;
CREATE POLICY "psychologist_services_delete_own" ON public.psychologist_services
FOR DELETE TO authenticated USING ((SELECT auth.uid()) = psychologist_id);
-- 5. Consolidated psychologists
DROP POLICY IF EXISTS "psychologists_insert_own" ON public.psychologists;
CREATE POLICY "psychologists_insert_own" ON public.psychologists
FOR INSERT TO authenticated WITH CHECK ((SELECT auth.uid()) = id);
DROP POLICY IF EXISTS "psychologists_update_own" ON public.psychologists;
CREATE POLICY "psychologists_update_own" ON public.psychologists
FOR UPDATE TO authenticated USING ((SELECT auth.uid()) = id);
-- 6. Consolidated psychology_specialties_catalog
DROP POLICY IF EXISTS "psychology_specialties_catalog_select_anon" ON public.psychology_specialties_catalog;
CREATE POLICY "psychology_specialties_catalog_select_anon" ON public.psychology_specialties_catalog
FOR SELECT TO anon USING (is_active = true);
DROP POLICY IF EXISTS "psychology_specialties_catalog_select_authenticated" ON public.psychology_specialties_catalog;
CREATE POLICY "psychology_specialties_catalog_select_authenticated" ON public.psychology_specialties_catalog
FOR SELECT TO authenticated USING (is_active = true);
-- 7. linktree_links (Refinement)
DROP POLICY IF EXISTS "linktree_links_select_public_or_own" ON public.linktree_links;
CREATE POLICY "linktree_links_select_public_or_own" ON public.linktree_links
FOR SELECT TO public USING (
    ((SELECT auth.uid()) = psychologist_id) OR 
    ((is_active = true) AND (EXISTS (
        SELECT 1 FROM public.psychologist_profiles pp 
        WHERE pp.id = psychologist_id AND pp.is_public = true
    )))
);
