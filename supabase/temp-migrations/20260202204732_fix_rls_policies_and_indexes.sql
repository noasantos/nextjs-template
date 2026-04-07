-- Migration: Fix RLS Policies, Duplicate Indexes, and Performance Issues
-- Created at: 2026-02-02 20:47:32
-- Issues:
--   - rls_enabled_no_policy: stripe_webhook_events sem políticas
--   - duplicate_index: índices duplicados em clinical_sessions e google_sync_idempotency
--   - multiple_permissive_policies: múltiplas políticas para mesma role/action
--   - auth_rls_initplan: auth.uid() sendo reavaliado a cada linha

-- =====================================================
-- 1. REMOVE ÍNDICES DUPLICADOS
-- =====================================================

-- clinical_sessions: idx_clinical_sessions_service_id é duplicado de idx_clinical_sessions_psychologist_service_id
DROP INDEX IF EXISTS public.idx_clinical_sessions_service_id;
-- google_sync_idempotency: idx_google_sync_idempotency_event_id é duplicado de idx_google_sync_idempotency_calendar_event_id
DROP INDEX IF EXISTS public.idx_google_sync_idempotency_event_id;
-- google_sync_idempotency: idx_google_sync_idempotency_psych_id é duplicado de idx_google_sync_idempotency_psychologist_id
DROP INDEX IF EXISTS public.idx_google_sync_idempotency_psych_id;
-- =====================================================
-- 2. CORRIGE RLS SEM POLÍTICA: stripe_webhook_events
-- =====================================================

-- Adiciona política para permitir apenas service_role (Edge Functions)
DROP POLICY IF EXISTS "stripe_webhook_events_service_access" ON public.stripe_webhook_events;
CREATE POLICY "stripe_webhook_events_service_access" 
ON public.stripe_webhook_events 
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);
-- =====================================================
-- 3. CONSOLIDA POLÍTICAS DUPLICADAS E OTIMIZA auth_rls_initplan
-- =====================================================

-- -----------------------------------------------------
-- google_calendar_connections
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Psychologists can view own connection" ON public.google_calendar_connections;
DROP POLICY IF EXISTS "Psychologists can insert own connection" ON public.google_calendar_connections;
DROP POLICY IF EXISTS "Psychologists can update own connection" ON public.google_calendar_connections;
DROP POLICY IF EXISTS "Psychologists can delete own connection" ON public.google_calendar_connections;
DROP POLICY IF EXISTS "google_calendar_connections_owner_access" ON public.google_calendar_connections;
DROP POLICY IF EXISTS "google_calendar_connections_crud" ON public.google_calendar_connections;
CREATE POLICY "google_calendar_connections_crud"
ON public.google_calendar_connections
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- calendar_event_series
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Psychologists can view own series" ON public.calendar_event_series;
DROP POLICY IF EXISTS "Psychologists can insert own series" ON public.calendar_event_series;
DROP POLICY IF EXISTS "Psychologists can update own series" ON public.calendar_event_series;
DROP POLICY IF EXISTS "Psychologists can delete own series" ON public.calendar_event_series;
DROP POLICY IF EXISTS "calendar_event_series_owner_access" ON public.calendar_event_series;
DROP POLICY IF EXISTS "calendar_event_series_crud" ON public.calendar_event_series;
CREATE POLICY "calendar_event_series_crud"
ON public.calendar_event_series
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- calendar_events
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Psychologists can view own events" ON public.calendar_events;
DROP POLICY IF EXISTS "Psychologists can insert own events" ON public.calendar_events;
DROP POLICY IF EXISTS "Psychologists can update own events" ON public.calendar_events;
DROP POLICY IF EXISTS "Psychologists can delete own events" ON public.calendar_events;
DROP POLICY IF EXISTS "calendar_events_owner_access" ON public.calendar_events;
DROP POLICY IF EXISTS "calendar_events_crud" ON public.calendar_events;
CREATE POLICY "calendar_events_crud"
ON public.calendar_events
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- calendar_event_series_exceptions
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Psychologists can manage exceptions via series" ON public.calendar_event_series_exceptions;
DROP POLICY IF EXISTS "series_exceptions_owner_access" ON public.calendar_event_series_exceptions;
DROP POLICY IF EXISTS "series_exceptions_crud" ON public.calendar_event_series_exceptions;
CREATE POLICY "series_exceptions_crud"
ON public.calendar_event_series_exceptions
FOR ALL
TO authenticated
USING (
    series_id IN (
        SELECT id FROM public.calendar_event_series 
        WHERE psychologist_id = (select auth.uid())
    )
)
WITH CHECK (
    series_id IN (
        SELECT id FROM public.calendar_event_series 
        WHERE psychologist_id = (select auth.uid())
    )
);
-- -----------------------------------------------------
-- google_sync_logs
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Psychologists can view own sync logs" ON public.google_sync_logs;
DROP POLICY IF EXISTS "google_sync_logs_owner_access" ON public.google_sync_logs;
DROP POLICY IF EXISTS "google_sync_logs_crud" ON public.google_sync_logs;
CREATE POLICY "google_sync_logs_crud"
ON public.google_sync_logs
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- sync_conflict_resolutions
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Users can view their own conflicts" ON public.sync_conflict_resolutions;
DROP POLICY IF EXISTS "Users can update their own conflicts" ON public.sync_conflict_resolutions;
DROP POLICY IF EXISTS "sync_conflict_resolutions_owner_access" ON public.sync_conflict_resolutions;
DROP POLICY IF EXISTS "sync_conflict_resolutions_crud" ON public.sync_conflict_resolutions;
CREATE POLICY "sync_conflict_resolutions_crud"
ON public.sync_conflict_resolutions
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- psychologist_assistants
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Psychologists can manage their assistants" ON public.psychologist_assistants;
DROP POLICY IF EXISTS "Assistants can see who they work for" ON public.psychologist_assistants;
DROP POLICY IF EXISTS "psychologist_assistants_psychologist_crud" ON public.psychologist_assistants;
CREATE POLICY "psychologist_assistants_psychologist_crud"
ON public.psychologist_assistants
FOR ALL
TO authenticated
USING (
    psychologist_id = (select auth.uid()) 
    OR assistant_id = (select auth.uid())
)
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- assistant_invites
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Psychologist can manage invites" ON public.assistant_invites;
DROP POLICY IF EXISTS "assistant_invites_crud" ON public.assistant_invites;
CREATE POLICY "assistant_invites_crud"
ON public.assistant_invites
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- psychologist_stripe_connect
-- -----------------------------------------------------
DROP POLICY IF EXISTS "psychologist_connect_read" ON public.psychologist_stripe_connect;
DROP POLICY IF EXISTS "psychologist_connect_write" ON public.psychologist_stripe_connect;
DROP POLICY IF EXISTS "psychologist_stripe_connect_crud" ON public.psychologist_stripe_connect;
CREATE POLICY "psychologist_stripe_connect_crud"
ON public.psychologist_stripe_connect
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- marketplace_payment_intents
-- -----------------------------------------------------
DROP POLICY IF EXISTS "psychologist_payments_read" ON public.marketplace_payment_intents;
DROP POLICY IF EXISTS "marketplace_payment_intents_crud" ON public.marketplace_payment_intents;
CREATE POLICY "marketplace_payment_intents_crud"
ON public.marketplace_payment_intents
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- google_sync_idempotency
-- -----------------------------------------------------
DROP POLICY IF EXISTS "google_sync_idempotency_insert_own" ON public.google_sync_idempotency;
DROP POLICY IF EXISTS "google_sync_idempotency_select_own" ON public.google_sync_idempotency;
DROP POLICY IF EXISTS "google_sync_idempotency_update_own" ON public.google_sync_idempotency;
DROP POLICY IF EXISTS "google_sync_idempotency_owner_access" ON public.google_sync_idempotency;
DROP POLICY IF EXISTS "google_sync_idempotency_crud" ON public.google_sync_idempotency;
CREATE POLICY "google_sync_idempotency_crud"
ON public.google_sync_idempotency
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- google_sync_queue
-- -----------------------------------------------------
DROP POLICY IF EXISTS "google_sync_queue_insert_own" ON public.google_sync_queue;
DROP POLICY IF EXISTS "google_sync_queue_select_own" ON public.google_sync_queue;
DROP POLICY IF EXISTS "google_sync_queue_update_own" ON public.google_sync_queue;
DROP POLICY IF EXISTS "google_sync_queue_owner_access" ON public.google_sync_queue;
DROP POLICY IF EXISTS "google_sync_queue_crud" ON public.google_sync_queue;
CREATE POLICY "google_sync_queue_crud"
ON public.google_sync_queue
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- patient_activity_assignments
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Access patient activities" ON public.patient_activity_assignments;
DROP POLICY IF EXISTS "patient_activity_assignments_owner_access" ON public.patient_activity_assignments;
DROP POLICY IF EXISTS "patient_activity_assignments_crud" ON public.patient_activity_assignments;
CREATE POLICY "patient_activity_assignments_crud"
ON public.patient_activity_assignments
FOR ALL
TO authenticated
USING (
    psychologist_id = (select auth.uid())
    OR has_access_to_psychologist_data(psychologist_id)
)
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- patient_tests
-- -----------------------------------------------------
DROP POLICY IF EXISTS "Access patient tests" ON public.patient_tests;
DROP POLICY IF EXISTS "patient_tests_owner_access" ON public.patient_tests;
DROP POLICY IF EXISTS "patient_tests_crud" ON public.patient_tests;
CREATE POLICY "patient_tests_crud"
ON public.patient_tests
FOR ALL
TO authenticated
USING (
    psychologist_id = (select auth.uid())
    OR has_access_to_psychologist_data(psychologist_id)
)
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- psychologist_locations
-- -----------------------------------------------------
DROP POLICY IF EXISTS "psychologist_locations_insert_own" ON public.psychologist_locations;
DROP POLICY IF EXISTS "psychologist_locations_select_own" ON public.psychologist_locations;
DROP POLICY IF EXISTS "psychologist_locations_update_own" ON public.psychologist_locations;
DROP POLICY IF EXISTS "psychologist_locations_delete_own" ON public.psychologist_locations;
DROP POLICY IF EXISTS "psychologist_locations_owner_access" ON public.psychologist_locations;
DROP POLICY IF EXISTS "psychologist_locations_crud" ON public.psychologist_locations;
CREATE POLICY "psychologist_locations_crud"
ON public.psychologist_locations
FOR ALL
TO authenticated
USING (psychologist_id = (select auth.uid()))
WITH CHECK (psychologist_id = (select auth.uid()));
-- -----------------------------------------------------
-- session_reschedule_requests
-- -----------------------------------------------------
DROP POLICY IF EXISTS "session_reschedule_requests_insert" ON public.session_reschedule_requests;
DROP POLICY IF EXISTS "session_reschedule_requests_select" ON public.session_reschedule_requests;
DROP POLICY IF EXISTS "session_reschedule_requests_update" ON public.session_reschedule_requests;
DROP POLICY IF EXISTS "session_reschedule_requests_delete" ON public.session_reschedule_requests;
DROP POLICY IF EXISTS "reschedule_requests_owner_access" ON public.session_reschedule_requests;
DROP POLICY IF EXISTS "session_reschedule_requests_crud" ON public.session_reschedule_requests;
CREATE POLICY "session_reschedule_requests_crud"
ON public.session_reschedule_requests
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s
        WHERE s.id = session_reschedule_requests.session_id
        AND s.psychologist_id = (select auth.uid())
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s
        WHERE s.id = session_reschedule_requests.session_id
        AND s.psychologist_id = (select auth.uid())
    )
);
-- -----------------------------------------------------
-- weekly_availability_configs
-- -----------------------------------------------------
DROP POLICY IF EXISTS "weekly_availability_configs_owner_access" ON public.weekly_availability_configs;
DROP POLICY IF EXISTS "weekly_availability_insert_own" ON public.weekly_availability_configs;
DROP POLICY IF EXISTS "weekly_availability_select_own" ON public.weekly_availability_configs;
DROP POLICY IF EXISTS "weekly_availability_update_own" ON public.weekly_availability_configs;
DROP POLICY IF EXISTS "weekly_availability_configs_crud" ON public.weekly_availability_configs;
CREATE POLICY "weekly_availability_configs_crud"
ON public.weekly_availability_configs
FOR ALL
TO authenticated
USING (user_id = (select auth.uid()))
WITH CHECK (user_id = (select auth.uid()));
