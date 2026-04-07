-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:25Z

SET check_function_bodies = false;

--
-- Name: google_sync_worker_metrics google_sync_worker_metrics_service_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY google_sync_worker_metrics_service_only ON public.google_sync_worker_metrics USING ((( SELECT auth.role() AS role) = 'service_role'::text)) WITH CHECK ((( SELECT auth.role() AS role) = 'service_role'::text));

--
-- Name: public_linktree_links linktree_links_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY linktree_links_owner_access ON public.public_linktree_links TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = psychologist_id)));

--
-- Name: psychologist_patient_activities patient_activity_assignments_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY patient_activity_assignments_crud ON public.psychologist_patient_activities TO authenticated USING (((psychologist_id = ( SELECT auth.uid() AS uid)) OR public.has_access_to_psychologist_data(psychologist_id))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: patient_deletion_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.patient_deletion_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: patient_deletion_audit_log patient_deletion_audit_log_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY patient_deletion_audit_log_admin ON public.patient_deletion_audit_log FOR SELECT TO authenticated USING (public.is_admin());

--
-- Name: psychologist_patient_assessments patient_tests_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY patient_tests_crud ON public.psychologist_patient_assessments TO authenticated USING (((psychologist_id = ( SELECT auth.uid() AS uid)) OR public.has_access_to_psychologist_data(psychologist_id))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: user_patients patients_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY patients_select ON public.user_patients FOR SELECT TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = id)));

--
-- Name: psychologist_assistants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_assistants ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_assistants psychologist_assistants_psychologist_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_assistants_psychologist_crud ON public.psychologist_assistants TO authenticated USING (((psychologist_id = ( SELECT auth.uid() AS uid)) OR (assistant_id = ( SELECT auth.uid() AS uid)))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: psychologist_weekly_schedules psychologist_availability_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_availability_owner_access ON public.psychologist_weekly_schedules TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = psychologist_id)));

--
-- Name: psychologist_patient_charges psychologist_client_charges_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_client_charges_owner_access ON public.psychologist_patient_charges TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = psychologist_id)));

--
-- Name: psychologist_clinical_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_clinical_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_financial_entries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_financial_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_financial_entries psychologist_financial_entries_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_financial_entries_owner_access ON public.psychologist_financial_entries TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = psychologist_id)));

--
-- Name: psychologist_invoices; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_invoices ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_invoices psychologist_invoices_service_role; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_invoices_service_role ON public.psychologist_invoices USING ((( SELECT auth.role() AS role) = 'service_role'::text)) WITH CHECK ((( SELECT auth.role() AS role) = 'service_role'::text));

--
-- Name: public_locations psychologist_locations_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_locations_crud ON public.public_locations TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: psychologist_notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_notes ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_onboarding_state; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_onboarding_state ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_onboarding_state psychologist_onboarding_state_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_onboarding_state_insert_own ON public.psychologist_onboarding_state FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = psychologist_id));

--
-- Name: psychologist_onboarding_state psychologist_onboarding_state_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_onboarding_state_select_own ON public.psychologist_onboarding_state FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = psychologist_id));

--
-- Name: psychologist_onboarding_state psychologist_onboarding_state_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_onboarding_state_update_own ON public.psychologist_onboarding_state FOR UPDATE TO authenticated USING ((( SELECT auth.uid() AS uid) = psychologist_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = psychologist_id));

--
-- Name: psychologist_patient_activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patient_activities ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_patient_assessments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patient_assessments ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_patient_charges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patient_charges ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_patient_emergency_contacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patient_emergency_contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_patient_guardian_documents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patient_guardian_documents ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_patient_guardians; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patient_guardians ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_patient_medical_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patient_medical_items ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_patient_services; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patient_services ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_patients; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_patients ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_preferences_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_preferences_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: public_profiles psychologist_profiles_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_profiles_insert_own ON public.public_profiles FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = id));

--
-- Name: public_profiles psychologist_profiles_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_profiles_select_own ON public.public_profiles FOR SELECT TO authenticated USING ((id = ( SELECT auth.uid() AS uid)));

--
-- Name: public_profiles psychologist_profiles_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_profiles_update_own ON public.public_profiles FOR UPDATE TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));

--
-- Name: psychologist_quick_notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_quick_notes ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_quick_notes psychologist_quick_notes_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_quick_notes_owner_access ON public.psychologist_quick_notes TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: psychologist_services; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_services ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_services psychologist_services_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_services_delete_own ON public.psychologist_services FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = psychologist_id));

--
-- Name: psychologist_services psychologist_services_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_services_insert_own ON public.psychologist_services FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = psychologist_id));

--
-- Name: psychologist_services psychologist_services_select_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_services_select_anon ON public.psychologist_services FOR SELECT TO anon USING (((is_active = true) AND public.is_profile_public(psychologist_id)));

--
-- Name: psychologist_services psychologist_services_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_services_select_authenticated ON public.psychologist_services FOR SELECT TO authenticated USING (((( SELECT auth.uid() AS uid) = psychologist_id) OR ((is_active = true) AND public.is_profile_public(psychologist_id))));

--
-- Name: psychologist_services psychologist_services_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_services_update_own ON public.psychologist_services FOR UPDATE TO authenticated USING ((( SELECT auth.uid() AS uid) = psychologist_id));

--
-- Name: psychologist_session_cancellation_policy; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_session_cancellation_policy ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_session_cancellation_policy psychologist_session_cancellation_policy_owner_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_session_cancellation_policy_owner_all ON public.psychologist_session_cancellation_policy TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: psychologist_stripe_connect; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_stripe_connect ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_stripe_connect psychologist_stripe_connect_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_stripe_connect_crud ON public.psychologist_stripe_connect TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: psychologist_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: psychologist_subscriptions psychologist_subscriptions_owner_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_subscriptions_owner_select ON public.psychologist_subscriptions FOR SELECT TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: psychologist_subscriptions psychologist_subscriptions_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologist_subscriptions_service_role_all ON public.psychologist_subscriptions TO service_role USING (true) WITH CHECK (true);

--
-- Name: psychologist_weekly_schedules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.psychologist_weekly_schedules ENABLE ROW LEVEL SECURITY;

--
-- Name: user_psychologists psychologists_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologists_insert_own ON public.user_psychologists FOR INSERT TO authenticated WITH CHECK ((( SELECT auth.uid() AS uid) = id));

--
-- Name: user_psychologists psychologists_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY psychologists_update_own ON public.user_psychologists FOR UPDATE TO authenticated USING ((( SELECT auth.uid() AS uid) = id));

--
-- Name: public_client_checkout_intents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.public_client_checkout_intents ENABLE ROW LEVEL SECURITY;

--
-- Name: public_client_checkout_intents public_client_checkout_intents_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_client_checkout_intents_select ON public.public_client_checkout_intents FOR SELECT TO authenticated USING (((psychologist_patient_id IN ( SELECT psychologist_patients.id
   FROM public.psychologist_patients
  WHERE (psychologist_patients.patient_id = ( SELECT auth.uid() AS uid)))) OR (psychologist_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM public.user_admins
  WHERE ((user_admins.id = ( SELECT auth.uid() AS uid)) AND (user_admins.is_active = true))))));

--
-- Name: public_linktree_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.public_linktree_links ENABLE ROW LEVEL SECURITY;

--
-- Name: public_linktree_links public_linktree_links_select_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_linktree_links_select_anon ON public.public_linktree_links FOR SELECT TO anon USING ((is_active = true));

--
-- Name: public_locations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.public_locations ENABLE ROW LEVEL SECURITY;

--
-- Name: public_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.public_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: public_profiles public_profiles_select_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_profiles_select_anon ON public.public_profiles FOR SELECT TO anon USING ((is_public = true));

--
-- Name: reference_values; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reference_values ENABLE ROW LEVEL SECURITY;

--
-- Name: reference_values reference_values_select_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY reference_values_select_anon ON public.reference_values FOR SELECT TO anon USING ((is_active = true));
