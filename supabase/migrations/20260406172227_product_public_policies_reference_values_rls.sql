-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:27Z

SET check_function_bodies = false;

--
-- Name: reference_values reference_values_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reference_values_select_authenticated ON public.reference_values FOR SELECT TO authenticated USING ((is_active = true));

--
-- Name: reference_values reference_values_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reference_values_service_role_all ON public.reference_values TO service_role USING (true) WITH CHECK (true);

--
-- Name: session_reschedule_logs reschedule_logs_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reschedule_logs_owner_access ON public.session_reschedule_logs TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.psychologist_clinical_sessions pcs
  WHERE ((pcs.id = session_reschedule_logs.session_id) AND (pcs.psychologist_id = ( SELECT auth.uid() AS uid))))));

--
-- Name: security_audit_events security_audit_actor_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY security_audit_actor_select_own ON public.security_audit_events FOR SELECT TO authenticated USING ((actor_id = ( SELECT auth.uid() AS uid)));

--
-- Name: security_audit_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.security_audit_events ENABLE ROW LEVEL SECURITY;

--
-- Name: security_audit_events security_audit_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY security_audit_service_role_all ON public.security_audit_events TO service_role USING (true) WITH CHECK (true);

--
-- Name: calendar_event_series_exceptions series_exceptions_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY series_exceptions_crud ON public.calendar_event_series_exceptions TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.calendar_event_series s
  WHERE ((s.id = calendar_event_series_exceptions.series_id) AND (s.psychologist_id = ( SELECT auth.uid() AS uid)))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.calendar_event_series s
  WHERE ((s.id = calendar_event_series_exceptions.series_id) AND (s.psychologist_id = ( SELECT auth.uid() AS uid))))));

--
-- Name: session_billing_dead_letter; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.session_billing_dead_letter ENABLE ROW LEVEL SECURITY;

--
-- Name: session_billing_dead_letter session_billing_dead_letter_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY session_billing_dead_letter_owner_access ON public.session_billing_dead_letter TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: clinical_session_details session_details_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY session_details_owner_access ON public.clinical_session_details TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.calendar_events e
  WHERE ((e.id = clinical_session_details.calendar_event_id) AND (e.psychologist_id = ( SELECT auth.uid() AS uid)))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.calendar_events e
  WHERE ((e.id = clinical_session_details.calendar_event_id) AND (e.psychologist_id = ( SELECT auth.uid() AS uid))))));

--
-- Name: session_reschedule_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.session_reschedule_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: session_reschedule_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.session_reschedule_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: session_reschedule_requests session_reschedule_requests_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY session_reschedule_requests_crud ON public.session_reschedule_requests TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.psychologist_clinical_sessions s
  WHERE ((s.id = session_reschedule_requests.session_id) AND (s.psychologist_id = ( SELECT auth.uid() AS uid)))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.psychologist_clinical_sessions s
  WHERE ((s.id = session_reschedule_requests.session_id) AND (s.psychologist_id = ( SELECT auth.uid() AS uid))))));

--
-- Name: session_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.session_types ENABLE ROW LEVEL SECURITY;

--
-- Name: session_types session_types_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY session_types_select_all ON public.session_types FOR SELECT TO authenticated USING (true);

--
-- Name: session_types session_types_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY session_types_select_authenticated ON public.session_types FOR SELECT TO authenticated USING (true);

--
-- Name: session_types session_types_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY session_types_service_role_all ON public.session_types TO service_role USING (true) WITH CHECK (true);

--
-- Name: stripe_idempotency_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stripe_idempotency_log ENABLE ROW LEVEL SECURITY;

--
-- Name: stripe_idempotency_log stripe_idempotency_log_service_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stripe_idempotency_log_service_only ON public.stripe_idempotency_log USING ((( SELECT auth.role() AS role) = 'service_role'::text)) WITH CHECK ((( SELECT auth.role() AS role) = 'service_role'::text));

--
-- Name: subscription_plans stripe_price_plans_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stripe_price_plans_select_public ON public.subscription_plans FOR SELECT TO authenticated, anon USING (true);

--
-- Name: POLICY stripe_price_plans_select_public ON subscription_plans; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY stripe_price_plans_select_public ON public.subscription_plans IS 'Allow anyone to read pricing plans (needed for pricing page before auth)';

--
-- Name: stripe_webhook_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;

--
-- Name: stripe_webhook_events stripe_webhook_events_service_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stripe_webhook_events_service_access ON public.stripe_webhook_events TO service_role USING (true) WITH CHECK (true);

--
-- Name: subscription_plans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

--
-- Name: sync_conflict_resolutions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sync_conflict_resolutions ENABLE ROW LEVEL SECURITY;

--
-- Name: sync_conflict_resolutions sync_conflict_resolutions_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sync_conflict_resolutions_crud ON public.sync_conflict_resolutions TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: sync_locks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sync_locks ENABLE ROW LEVEL SECURITY;

--
-- Name: sync_locks sync_locks_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY sync_locks_admin ON public.sync_locks FOR SELECT TO authenticated USING (public.is_admin());

--
-- Name: unified_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.unified_events ENABLE ROW LEVEL SECURITY;

--
-- Name: unified_events unified_events_auth_operational; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY unified_events_auth_operational ON public.unified_events FOR SELECT TO authenticated USING ((event_family = 'operational'::text));

--
-- Name: unified_events unified_events_service_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY unified_events_service_all ON public.unified_events TO service_role USING (true) WITH CHECK (true);

--
-- Name: user_admins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_admins ENABLE ROW LEVEL SECURITY;

--
-- Name: user_assistants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_assistants ENABLE ROW LEVEL SECURITY;

--
-- Name: user_patients; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_patients ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_preferences_audit_log user_preferences_audit_log_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_preferences_audit_log_owner_access ON public.psychologist_preferences_audit_log TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = user_id)));

--
-- Name: psychologist_preferences user_preferences_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_preferences_owner_access ON public.psychologist_preferences TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = user_id)));

--
-- Name: user_psychologists; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_psychologists ENABLE ROW LEVEL SECURITY;

--
-- Name: user_psychologists user_psychologists_select_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_psychologists_select_anon ON public.user_psychologists FOR SELECT TO anon USING (true);

--
-- Name: webhook_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.webhook_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: webhook_audit_log webhook_audit_service_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY webhook_audit_service_only ON public.webhook_audit_log TO authenticated USING (false);

--
-- Name: webhook_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.webhook_events ENABLE ROW LEVEL SECURITY;

--
-- Name: webhook_events webhook_events_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY webhook_events_admin ON public.webhook_events FOR SELECT TO authenticated USING (public.is_admin());


--
-- PostgreSQL database dump complete
--

SET check_function_bodies = true;
