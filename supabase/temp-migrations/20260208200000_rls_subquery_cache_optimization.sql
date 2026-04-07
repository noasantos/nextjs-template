-- ============================================================
-- Migration: RLS Subquery Cache Optimization (Phase 1)
-- 
-- Wraps all remaining bare auth.uid() calls in RLS policies with
-- (SELECT auth.uid()) to enable PostgreSQL initPlan caching.
-- 
-- Without the subquery wrapper, Postgres evaluates auth.uid() once
-- per row scanned. With the wrapper, the planner executes an initPlan
-- that caches the result for the entire query duration.
--
-- Impact: Reduces RLS overhead from O(n) function calls to O(1)
-- on tables with high row counts (clinical_notes, calendar_events, etc.)
--
-- Tables affected (from migrations analysis):
--   - psychologist_profiles (core_schema)
--   - google_calendar_connections (infrastructure_and_catalogs)
--   - calendar_event_series (infrastructure_and_catalogs)
--   - calendar_events (infrastructure_and_catalogs)
--   - calendar_event_series_exceptions (infrastructure_and_catalogs)
--   - clinical_session_details (infrastructure_and_catalogs)
--   - google_sync_logs (infrastructure_and_catalogs)
--   - sync_conflict_resolutions (infrastructure_and_catalogs)
--   - psychologist_stripe_connect (stripe_connect_marketplace)
--   - marketplace_payment_intents (stripe_connect_marketplace)
--   - storage.objects (secure_storage_buckets)
-- ============================================================

-- -------------------------------------------------------
-- 1. psychologist_profiles — core_schema original policies
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "psychologist_profiles_select_own" ON public.psychologist_profiles;
  CREATE POLICY "psychologist_profiles_select_own"
    ON public.psychologist_profiles
    FOR SELECT TO authenticated
    USING (id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped psychologist_profiles_select_own: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "psychologist_profiles_update_own" ON public.psychologist_profiles;
  CREATE POLICY "psychologist_profiles_update_own"
    ON public.psychologist_profiles
    FOR UPDATE TO authenticated
    USING (id = (SELECT auth.uid()))
    WITH CHECK (id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped psychologist_profiles_update_own: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 2. google_calendar_connections
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can view own connection" ON public.google_calendar_connections;
  CREATE POLICY "Psychologists can view own connection"
    ON public.google_calendar_connections FOR SELECT TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped google_calendar_connections select: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can insert own connection" ON public.google_calendar_connections;
  CREATE POLICY "Psychologists can insert own connection"
    ON public.google_calendar_connections FOR INSERT TO authenticated
    WITH CHECK (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped google_calendar_connections insert: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can update own connection" ON public.google_calendar_connections;
  CREATE POLICY "Psychologists can update own connection"
    ON public.google_calendar_connections FOR UPDATE TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped google_calendar_connections update: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can delete own connection" ON public.google_calendar_connections;
  CREATE POLICY "Psychologists can delete own connection"
    ON public.google_calendar_connections FOR DELETE TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped google_calendar_connections delete: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 3. calendar_event_series
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can view own series" ON public.calendar_event_series;
  CREATE POLICY "Psychologists can view own series"
    ON public.calendar_event_series FOR SELECT TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_event_series select: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can insert own series" ON public.calendar_event_series;
  CREATE POLICY "Psychologists can insert own series"
    ON public.calendar_event_series FOR INSERT TO authenticated
    WITH CHECK (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_event_series insert: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can update own series" ON public.calendar_event_series;
  CREATE POLICY "Psychologists can update own series"
    ON public.calendar_event_series FOR UPDATE TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_event_series update: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can delete own series" ON public.calendar_event_series;
  CREATE POLICY "Psychologists can delete own series"
    ON public.calendar_event_series FOR DELETE TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_event_series delete: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 4. calendar_events
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can view own events" ON public.calendar_events;
  CREATE POLICY "Psychologists can view own events"
    ON public.calendar_events FOR SELECT TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_events select: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can insert own events" ON public.calendar_events;
  CREATE POLICY "Psychologists can insert own events"
    ON public.calendar_events FOR INSERT TO authenticated
    WITH CHECK (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_events insert: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can update own events" ON public.calendar_events;
  CREATE POLICY "Psychologists can update own events"
    ON public.calendar_events FOR UPDATE TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_events update: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can delete own events" ON public.calendar_events;
  CREATE POLICY "Psychologists can delete own events"
    ON public.calendar_events FOR DELETE TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_events delete: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 5. calendar_event_series_exceptions
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can manage exceptions via series" ON public.calendar_event_series_exceptions;
  CREATE POLICY "Psychologists can manage exceptions via series"
    ON public.calendar_event_series_exceptions FOR ALL TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.calendar_event_series s
        WHERE s.id = series_id AND s.psychologist_id = (SELECT auth.uid())
      )
    );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped calendar_event_series_exceptions: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 6. clinical_session_details
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can manage session details via event" ON public.clinical_session_details;
  CREATE POLICY "Psychologists can manage session details via event"
    ON public.clinical_session_details FOR ALL TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.calendar_events e
        WHERE e.id = calendar_event_id AND e.psychologist_id = (SELECT auth.uid())
      )
    );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped clinical_session_details: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 7. google_sync_logs
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "Psychologists can view own sync logs" ON public.google_sync_logs;
  CREATE POLICY "Psychologists can view own sync logs"
    ON public.google_sync_logs FOR SELECT TO authenticated
    USING (psychologist_id = (SELECT auth.uid()));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped google_sync_logs select: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 8. sync_conflict_resolutions
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can view their own conflicts" ON public.sync_conflict_resolutions;
  CREATE POLICY "Users can view their own conflicts"
    ON public.sync_conflict_resolutions FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = psychologist_id);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped sync_conflict_resolutions select: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can update their own conflicts" ON public.sync_conflict_resolutions;
  CREATE POLICY "Users can update their own conflicts"
    ON public.sync_conflict_resolutions FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = psychologist_id);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped sync_conflict_resolutions update: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 9. psychologist_stripe_connect
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS psychologist_connect_read ON public.psychologist_stripe_connect;
  CREATE POLICY psychologist_connect_read
    ON public.psychologist_stripe_connect FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) IS NOT NULL AND (SELECT auth.uid()) = psychologist_id);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped psychologist_stripe_connect read: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 10. marketplace_payment_intents
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS psychologist_payments_read ON public.marketplace_payment_intents;
  CREATE POLICY psychologist_payments_read
    ON public.marketplace_payment_intents FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) IS NOT NULL AND (SELECT auth.uid()) = psychologist_id);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped marketplace_payment_intents read: %', SQLERRM;
END $$;
-- -------------------------------------------------------
-- 11. storage.objects — patient-documents bucket
-- -------------------------------------------------------
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can read own documents" ON storage.objects;
  CREATE POLICY "Users can read own documents" ON storage.objects
    FOR SELECT TO authenticated
    USING (
      bucket_id = 'patient-documents' AND
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped storage read: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can upload to own folder" ON storage.objects;
  CREATE POLICY "Users can upload to own folder" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'patient-documents' AND
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped storage insert: %', SQLERRM;
END $$;
DO $$ BEGIN
  DROP POLICY IF EXISTS "Users can delete own documents" ON storage.objects;
  CREATE POLICY "Users can delete own documents" ON storage.objects
    FOR DELETE TO authenticated
    USING (
      bucket_id = 'patient-documents' AND
      (storage.foldername(name))[1] = (SELECT auth.uid())::text
    );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Skipped storage delete: %', SQLERRM;
END $$;
-- ============================================================
-- VERIFICATION: Confirm no bare auth.uid() remains in policies
-- Run after migration:
--   SELECT tablename, policyname, qual, with_check
--   FROM pg_policies
--   WHERE schemaname = 'public'
--     AND (
--       (qual LIKE '%auth.uid()%' AND qual NOT LIKE '%(select auth.uid())%' AND qual NOT LIKE '%(SELECT auth.uid())%')
--       OR (with_check LIKE '%auth.uid()%' AND with_check NOT LIKE '%(select auth.uid())%' AND with_check NOT LIKE '%(SELECT auth.uid())%')
--     );
-- Expected: 0 rows
-- ============================================================;
