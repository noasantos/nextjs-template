-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:22Z

SET check_function_bodies = false;

--
-- Name: sync_conflict_resolutions sync_conflict_resolutions_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_conflict_resolutions
    ADD CONSTRAINT sync_conflict_resolutions_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES auth.users(id) ON DELETE CASCADE;

--
-- Name: psychologist_patients Access clients; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Access clients" ON public.psychologist_patients USING (public.has_access_to_psychologist_data(psychologist_id)) WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));

--
-- Name: generated_documents Access generated documents; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Access generated documents" ON public.generated_documents USING (public.has_access_to_psychologist_data(psychologist_id)) WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));

--
-- Name: psychologist_patient_guardian_documents Access guardian documents; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Access guardian documents" ON public.psychologist_patient_guardian_documents USING (public.has_access_to_psychologist_data(psychologist_id)) WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));

--
-- Name: psychologist_patient_guardians Access guardians; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Access guardians" ON public.psychologist_patient_guardians USING (public.has_access_to_psychologist_data(psychologist_id)) WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));

--
-- Name: psychologist_patient_medical_items Access medical items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Access medical items" ON public.psychologist_patient_medical_items USING (public.has_access_to_psychologist_data(psychologist_id)) WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));

--
-- Name: psychologist_notes Access notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Access notes" ON public.psychologist_notes USING (public.has_access_to_psychologist_data(psychologist_id)) WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));

--
-- Name: psychologist_clinical_sessions Access sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Access sessions" ON public.psychologist_clinical_sessions USING (public.has_access_to_psychologist_data(psychologist_id)) WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));

--
-- Name: calendar_holidays Allow authenticated users to read holidays; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow authenticated users to read holidays" ON public.calendar_holidays FOR SELECT TO authenticated USING (true);

--
-- Name: psychologist_patient_services Psychologists can manage client services; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Psychologists can manage client services" ON public.psychologist_patient_services TO authenticated USING ((( SELECT auth.uid() AS uid) = psychologist_id));

--
-- Name: psychologist_patient_emergency_contacts Psychologists can manage patient emergency contacts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Psychologists can manage patient emergency contacts" ON public.psychologist_patient_emergency_contacts TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.psychologist_patients pp
  WHERE ((pp.id = psychologist_patient_emergency_contacts.psychologist_patient_id) AND (pp.psychologist_id = ( SELECT auth.uid() AS uid)))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.psychologist_patients pp
  WHERE ((pp.id = psychologist_patient_emergency_contacts.psychologist_patient_id) AND (pp.psychologist_id = ( SELECT auth.uid() AS uid))))));

--
-- Name: POLICY "Psychologists can manage patient emergency contacts" ON psychologist_patient_emergency_contacts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY "Psychologists can manage patient emergency contacts" ON public.psychologist_patient_emergency_contacts IS 'Allow psychologists to manage emergency contacts only for their own patients (via psychologist_patients)';

--
-- Name: google_sync_logs Service role can insert sync logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role can insert sync logs" ON public.google_sync_logs FOR INSERT TO service_role WITH CHECK (true);

--
-- Name: account_deletion_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: account_deletion_requests account_deletion_requests_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_deletion_requests_insert_own ON public.account_deletion_requests FOR INSERT TO authenticated WITH CHECK (((requested_by = ( SELECT auth.uid() AS uid)) AND (user_id = ( SELECT auth.uid() AS uid))));

--
-- Name: account_deletion_requests account_deletion_requests_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_deletion_requests_select_own ON public.account_deletion_requests FOR SELECT TO authenticated USING ((requested_by = ( SELECT auth.uid() AS uid)));

--
-- Name: account_deletion_requests account_deletion_requests_service_role_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY account_deletion_requests_service_role_all ON public.account_deletion_requests TO service_role USING (true) WITH CHECK (true);

--
-- Name: user_admins admins_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admins_select ON public.user_admins FOR SELECT TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = id)));

--
-- Name: assistant_invites; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assistant_invites ENABLE ROW LEVEL SECURITY;

--
-- Name: assistant_invites assistant_invites_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assistant_invites_crud ON public.assistant_invites TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: user_assistants assistants_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assistants_select ON public.user_assistants FOR SELECT TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = id)));

--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs audit_logs_no_modify; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_no_modify ON public.audit_logs AS RESTRICTIVE TO authenticated USING (false) WITH CHECK (false);

--
-- Name: audit_logs audit_logs_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_select ON public.audit_logs FOR SELECT TO authenticated USING (((( SELECT auth.uid() AS uid) = user_id) OR (EXISTS ( SELECT 1
   FROM public.user_admins
  WHERE ((user_admins.id = ( SELECT auth.uid() AS uid)) AND (user_admins.is_active = true)))) OR (EXISTS ( SELECT 1
   FROM public.psychologist_patients pp
  WHERE ((pp.psychologist_id = ( SELECT auth.uid() AS uid)) AND ((pp.id)::text = audit_logs.record_id)))) OR (EXISTS ( SELECT 1
   FROM public.psychologist_clinical_sessions pcs
  WHERE ((pcs.psychologist_id = ( SELECT auth.uid() AS uid)) AND ((pcs.id)::text = audit_logs.record_id)))) OR (EXISTS ( SELECT 1
   FROM public.psychologist_notes pn
  WHERE ((pn.psychologist_id = ( SELECT auth.uid() AS uid)) AND ((pn.id)::text = audit_logs.record_id))))));

--
-- Name: availability_exceptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.availability_exceptions ENABLE ROW LEVEL SECURITY;

--
-- Name: availability_exceptions availability_exceptions_owner_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY availability_exceptions_owner_access ON public.availability_exceptions TO authenticated USING ((public.is_admin() OR (( SELECT auth.uid() AS uid) = psychologist_id)));

--
-- Name: busy_slots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.busy_slots ENABLE ROW LEVEL SECURITY;

--
-- Name: busy_slots busy_slots_owner_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY busy_slots_owner_read ON public.busy_slots FOR SELECT TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: busy_slots busy_slots_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY busy_slots_public_read ON public.busy_slots FOR SELECT TO anon USING (true);

--
-- Name: busy_slots busy_slots_service_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY busy_slots_service_manage ON public.busy_slots TO service_role USING (true) WITH CHECK (true);

--
-- Name: calendar_change_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.calendar_change_log ENABLE ROW LEVEL SECURITY;

--
-- Name: calendar_change_log calendar_change_log_service_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY calendar_change_log_service_only ON public.calendar_change_log USING ((( SELECT auth.role() AS role) = 'service_role'::text)) WITH CHECK ((( SELECT auth.role() AS role) = 'service_role'::text));

--
-- Name: calendar_event_series; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.calendar_event_series ENABLE ROW LEVEL SECURITY;

--
-- Name: calendar_event_series calendar_event_series_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY calendar_event_series_crud ON public.calendar_event_series TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: calendar_event_series_exceptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.calendar_event_series_exceptions ENABLE ROW LEVEL SECURITY;

--
-- Name: calendar_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

--
-- Name: calendar_events calendar_events_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY calendar_events_crud ON public.calendar_events TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: calendar_holidays; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.calendar_holidays ENABLE ROW LEVEL SECURITY;

--
-- Name: catalog_clinical_activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.catalog_clinical_activities ENABLE ROW LEVEL SECURITY;

--
-- Name: catalog_document_templates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.catalog_document_templates ENABLE ROW LEVEL SECURITY;

--
-- Name: catalog_clinical_activities clinical_activities_catalog_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clinical_activities_catalog_read ON public.catalog_clinical_activities FOR SELECT TO authenticated USING ((active = true));

--
-- Name: clinical_session_details; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.clinical_session_details ENABLE ROW LEVEL SECURITY;

--
-- Name: clinical_session_details clinical_session_details_psychologist_access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clinical_session_details_psychologist_access ON public.clinical_session_details TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.calendar_events e
  WHERE ((e.id = clinical_session_details.calendar_event_id) AND (e.psychologist_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.calendar_events e
  WHERE ((e.id = clinical_session_details.calendar_event_id) AND (e.psychologist_id = auth.uid())))));

--
-- Name: catalog_document_templates document_templates_global_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY document_templates_global_read ON public.catalog_document_templates FOR SELECT TO authenticated USING (true);

--
-- Name: encryption_audit_log encryption_audit_deny_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY encryption_audit_deny_public ON public.encryption_audit_log USING (false);

--
-- Name: encryption_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.encryption_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: encryption_audit_log encryption_audit_log_service_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY encryption_audit_log_service_only ON public.encryption_audit_log TO service_role USING (true) WITH CHECK (true);

--
-- Name: encryption_audit_log encryption_audit_service_view; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY encryption_audit_service_view ON public.encryption_audit_log FOR SELECT TO service_role USING (true);

--
-- Name: generated_documents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.generated_documents ENABLE ROW LEVEL SECURITY;

--
-- Name: google_calendar_connections; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_calendar_connections ENABLE ROW LEVEL SECURITY;

--
-- Name: google_calendar_connections google_calendar_connections_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY google_calendar_connections_crud ON public.google_calendar_connections TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: google_sync_idempotency; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_sync_idempotency ENABLE ROW LEVEL SECURITY;

--
-- Name: google_sync_idempotency google_sync_idempotency_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY google_sync_idempotency_crud ON public.google_sync_idempotency TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid))) WITH CHECK ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: google_sync_inbound_coalesce; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_sync_inbound_coalesce ENABLE ROW LEVEL SECURITY;

--
-- Name: google_sync_inbound_coalesce google_sync_inbound_coalesce_service_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY google_sync_inbound_coalesce_service_only ON public.google_sync_inbound_coalesce USING ((( SELECT auth.role() AS role) = 'service_role'::text)) WITH CHECK ((( SELECT auth.role() AS role) = 'service_role'::text));

--
-- Name: google_sync_job_dedup; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_sync_job_dedup ENABLE ROW LEVEL SECURITY;

--
-- Name: google_sync_job_dedup google_sync_job_dedup_service_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY google_sync_job_dedup_service_only ON public.google_sync_job_dedup USING ((( SELECT auth.role() AS role) = 'service_role'::text)) WITH CHECK ((( SELECT auth.role() AS role) = 'service_role'::text));

--
-- Name: google_sync_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_sync_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: google_sync_logs google_sync_logs_crud; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY google_sync_logs_crud ON public.google_sync_logs TO authenticated USING ((psychologist_id = ( SELECT auth.uid() AS uid)));

--
-- Name: google_sync_worker_metrics; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.google_sync_worker_metrics ENABLE ROW LEVEL SECURITY;
