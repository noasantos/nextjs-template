-- Security Advisor Fixes

-- 1. Fix Function Search Paths (Security: prevents search_path shadowing attacks)
ALTER FUNCTION public.check_calendar_conflicts(uuid, timestamptz, timestamptz, uuid) SET search_path = public;
ALTER FUNCTION public.text_to_lexical_base64(text) SET search_path = public;
ALTER FUNCTION public.handle_user_preferences_audit() SET search_path = public;
ALTER FUNCTION public.update_psychologist_subscriptions_trigger() SET search_path = public;
ALTER FUNCTION public.update_psychologist_clients_updated_at() SET search_path = public;
ALTER FUNCTION public.update_clinical_sessions_updated_at() SET search_path = public;
ALTER FUNCTION public.empty_lexical_state_base64() SET search_path = public;
ALTER FUNCTION public.get_jwt_claim_role() SET search_path = public;
ALTER FUNCTION public.update_psychologist_availability_updated_at() SET search_path = public;
ALTER FUNCTION public.cleanup_orphaned_weekly_consolidations() SET search_path = public;
ALTER FUNCTION public.cleanup_expired_patient_deletions() SET search_path = public;
ALTER FUNCTION public.encrypt_token_base64(text, text) SET search_path = public;
ALTER FUNCTION public.decrypt_token_base64(text, text) SET search_path = public;
ALTER FUNCTION public.get_upcoming_exceptions(uuid, date, integer) SET search_path = public;
ALTER FUNCTION public.update_calendar_updated_at() SET search_path = public;
ALTER FUNCTION public.validate_weekly_availability_overlaps(uuid, integer, jsonb) SET search_path = public;
-- 2. Move Extension to Extensions Schema (Security: keeps public schema clean)
CREATE SCHEMA IF NOT EXISTS extensions;
-- Handle moddatetime if it exists in public
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'moddatetime') THEN
    ALTER EXTENSION moddatetime SET SCHEMA extensions;
  END IF;
END $$;
-- 3. Fix RLS Policy Always True (Security: restrict insert access)
-- Table: public.google_sync_logs
-- Policy: Service role can insert sync logs
-- Previous: WITH CHECK (true)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_logs' AND schemaname = 'public') THEN
        DROP POLICY IF EXISTS "Service role can insert sync logs" ON public.google_sync_logs;
        CREATE POLICY "Service role can insert sync logs" ON public.google_sync_logs
          FOR INSERT 
          TO service_role 
          WITH CHECK (true);
    END IF;
END $$;
