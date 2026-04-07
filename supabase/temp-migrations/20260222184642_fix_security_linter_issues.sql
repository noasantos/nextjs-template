-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T18:46:42Z

-- =============================================================================
-- SECURITY LINTER FIXES
-- Fixes for: security_definer_view, function_search_path_mutable, 
--            rls_enabled_no_policy, auth_rls_initplan, duplicate_index
-- =============================================================================

-- =============================================================================
-- 1. FIX SECURITY DEFINER VIEWS - Change to SECURITY INVOKER
-- =============================================================================

-- View: psychologist_onboarding_status
DROP VIEW IF EXISTS public.psychologist_onboarding_status;
CREATE VIEW public.psychologist_onboarding_status
WITH (SECURITY_INVOKER)
AS
SELECT psychologist_id,
    current_step,
    completion_percentage,
    total_steps,
    identity_step_completed,
    professional_step_completed,
    payment_step_completed,
    configuration_step_completed,
    profile_step_completed,
    (identity_step_completed AND professional_step_completed AND payment_step_completed) AS essential_complete,
    (identity_step_completed AND professional_step_completed AND payment_step_completed AND configuration_step_completed AND profile_step_completed) AS fully_complete,
        CASE
            WHEN (onboarding_completed_at IS NOT NULL) THEN 'completed'::text
            WHEN (identity_step_completed AND professional_step_completed AND payment_step_completed) THEN 'in_progress'::text
            ELSE 'pending'::text
        END AS status,
    onboarding_completed_at,
    last_resumed_at,
    abandoned_at
   FROM psychologist_onboarding_state;
-- View: psychologist_onboarding_summary
DROP VIEW IF EXISTS public.psychologist_onboarding_summary;
CREATE VIEW public.psychologist_onboarding_summary
WITH (SECURITY_INVOKER)
AS
SELECT pos.psychologist_id,
    pos.payment_step_completed,
    pos.identity_step_completed,
    pos.professional_step_completed,
    pos.configuration_step_completed,
    pos.profile_step_completed,
    pos.current_step,
    pos.total_steps,
    pos.completion_percentage,
    pos.onboarding_completed_at,
    pos.last_resumed_at,
    pos.abandoned_at,
    (COALESCE((up.subscription_status = ANY (ARRAY['active'::text, 'trialing'::text])), false) OR pos.payment_step_completed) AS essential_complete,
    ((pos.onboarding_completed_at IS NOT NULL) OR (pos.payment_step_completed AND pos.identity_step_completed AND pos.professional_step_completed AND pos.configuration_step_completed AND pos.profile_step_completed)) AS fully_complete,
        CASE
            WHEN (pos.onboarding_completed_at IS NOT NULL) THEN NULL::text
            WHEN (NOT pos.payment_step_completed) THEN 'subscription'::text
            WHEN (NOT pos.identity_step_completed) THEN 'identity'::text
            WHEN (NOT pos.professional_step_completed) THEN 'professional'::text
            WHEN (NOT pos.configuration_step_completed) THEN 'configuration'::text
            WHEN (NOT pos.profile_step_completed) THEN 'profile'::text
            ELSE NULL::text
        END AS next_pending_step,
    up.subscription_status
   FROM (psychologist_onboarding_state pos
     LEFT JOIN user_psychologists up ON ((up.id = pos.psychologist_id)));
-- View: v_operational_events
DROP VIEW IF EXISTS public.v_operational_events;
CREATE VIEW public.v_operational_events
WITH (SECURITY_INVOKER)
AS
SELECT id,
    event_family,
    event_name,
    "timestamp",
    trace_id,
    correlation_id,
    service,
    component,
    environment,
    actor_type,
    actor_id_hash,
    role,
    operation,
    operation_type,
    outcome,
    error_category,
    error_code,
    error_message,
    duration_ms,
    metadata,
    sample_rate,
    force_keep,
    retention_days,
    request_path,
    http_status,
    ip_address,
    user_agent
   FROM unified_events
  WHERE (event_family = 'operational'::text);
-- View: v_service_role_audit
DROP VIEW IF EXISTS public.v_service_role_audit;
CREATE VIEW public.v_service_role_audit
WITH (SECURITY_INVOKER)
AS
SELECT id,
    event_family,
    event_name,
    "timestamp",
    trace_id,
    correlation_id,
    service,
    component,
    environment,
    actor_type,
    actor_id_hash,
    role,
    operation,
    operation_type,
    outcome,
    error_category,
    error_code,
    error_message,
    duration_ms,
    metadata,
    sample_rate,
    force_keep,
    retention_days,
    request_path,
    http_status,
    ip_address,
    user_agent
   FROM unified_events
  WHERE (event_family = 'security_audit'::text);
-- View: v_stripe_webhook_events
DROP VIEW IF EXISTS public.v_stripe_webhook_events;
CREATE VIEW public.v_stripe_webhook_events
WITH (SECURITY_INVOKER)
AS
SELECT id,
    "timestamp",
    event_name,
    operation AS stripe_event_type,
    (metadata ->> 'stripe_event_id'::text) AS stripe_event_id,
    (metadata ->> 'customer_id'::text) AS customer_id,
    (metadata ->> 'subscription_id'::text) AS subscription_id,
    outcome,
    error_message,
    duration_ms
   FROM unified_events
  WHERE (event_family = 'stripe_webhook'::text);
-- =============================================================================
-- 2. FIX FUNCTION SEARCH PATH MUTABLE - Add SET search_path
-- =============================================================================

-- Function: calculate_onboarding_progress(uuid) - legacy version without search_path
DROP FUNCTION IF EXISTS public.calculate_onboarding_progress(uuid);
-- Function: complete_onboarding_step(text) - legacy version without search_path
DROP FUNCTION IF EXISTS public.complete_onboarding_step(text);
-- Function: can_user_access_app() - legacy version without search_path
DROP FUNCTION IF EXISTS public.can_user_access_app();
-- Function: update_onboarding_progress - trigger function needs search_path
CREATE OR REPLACE FUNCTION public.update_onboarding_progress()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  v_progress INTEGER;
  v_new_step INTEGER;
BEGIN
  -- Calculate progress
  v_progress := calculate_onboarding_progress(NEW.psychologist_id);
  
  -- Determine current step based on completion status
  -- Order: identity (1) → professional (2) → payment (3) → configuration (4) → profile (5)
  IF NOT NEW.identity_step_completed THEN
    v_new_step := 1;
  ELSIF NOT NEW.professional_step_completed THEN
    v_new_step := 2;
  ELSIF NOT NEW.payment_step_completed THEN
    v_new_step := 3;
  ELSIF NOT NEW.configuration_step_completed THEN
    v_new_step := 4;
  ELSIF NOT NEW.profile_step_completed THEN
    v_new_step := 5;
  ELSE
    v_new_step := 6; -- complete
  END IF;
  
  -- Update calculated fields only if changed
  IF NEW.completion_percentage IS DISTINCT FROM v_progress 
     OR NEW.current_step IS DISTINCT FROM v_new_step THEN
    NEW.completion_percentage := v_progress;
    NEW.current_step := v_new_step;
  END IF;
  
  RETURN NEW;
END;
$function$;
-- =============================================================================
-- 3. FIX RLS ENABLED NO POLICY - Add policies for unified_events
-- =============================================================================

-- Allow service_role to manage all events
CREATE POLICY unified_events_service_all ON public.unified_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
-- Allow authenticated users to view operational events
CREATE POLICY unified_events_auth_operational ON public.unified_events
  FOR SELECT
  TO authenticated
  USING (event_family = 'operational'::text);
-- =============================================================================
-- 4. FIX AUTH RLS INIT PLAN - Wrap auth.uid() with SELECT for performance
-- =============================================================================

-- Drop and recreate policies for psychologist_onboarding_state
DROP POLICY IF EXISTS psychologist_onboarding_state_select_own ON public.psychologist_onboarding_state;
CREATE POLICY psychologist_onboarding_state_select_own ON public.psychologist_onboarding_state
  FOR SELECT
  TO authenticated
  USING (((select auth.uid()) = psychologist_id));
DROP POLICY IF EXISTS psychologist_onboarding_state_update_own ON public.psychologist_onboarding_state;
CREATE POLICY psychologist_onboarding_state_update_own ON public.psychologist_onboarding_state
  FOR UPDATE
  TO authenticated
  USING (((select auth.uid()) = psychologist_id))
  WITH CHECK (((select auth.uid()) = psychologist_id));
DROP POLICY IF EXISTS psychologist_onboarding_state_insert_own ON public.psychologist_onboarding_state;
CREATE POLICY psychologist_onboarding_state_insert_own ON public.psychologist_onboarding_state
  FOR INSERT
  TO authenticated
  WITH CHECK (((select auth.uid()) = psychologist_id));
-- Drop and recreate policy for session_reschedule_logs
DROP POLICY IF EXISTS reschedule_logs_owner_access ON public.session_reschedule_logs;
CREATE POLICY reschedule_logs_owner_access ON public.session_reschedule_logs
  FOR ALL
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM psychologist_clinical_sessions pcs
  WHERE ((pcs.id = session_reschedule_logs.session_id) AND (pcs.psychologist_id = (select auth.uid()))))));
-- =============================================================================
-- 5. FIX DUPLICATE INDEX - Drop duplicate index
-- =============================================================================

-- Drop the duplicate index (keeping idx_patient_emergency_contacts_psychologist_client_id)
DROP INDEX IF EXISTS public.idx_psychologist_patient_emergency_contacts_psychologist_patien;
