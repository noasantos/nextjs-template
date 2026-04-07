-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:16Z

SET check_function_bodies = false;

--
-- Name: psychologist_onboarding_state trg_update_onboarding_progress; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_onboarding_progress BEFORE INSERT OR UPDATE ON public.psychologist_onboarding_state FOR EACH ROW EXECUTE FUNCTION public.update_onboarding_progress();

--
-- Name: calendar_events trigger_enqueue_google_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_enqueue_google_sync AFTER INSERT OR DELETE OR UPDATE ON public.calendar_events FOR EACH ROW EXECUTE FUNCTION public.enqueue_event_for_google_sync_v3();

--
-- Name: psychologist_patients trigger_generate_display_name; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_generate_display_name BEFORE INSERT OR UPDATE OF manual_first_name, manual_last_name, manual_preferred_name ON public.psychologist_patients FOR EACH ROW EXECUTE FUNCTION public.generate_patient_display_name();

--
-- Name: user_patients trigger_generate_public_patient_display_name; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_generate_public_patient_display_name BEFORE INSERT OR UPDATE OF first_name, last_name, preferred_name ON public.user_patients FOR EACH ROW EXECUTE FUNCTION public.generate_public_patient_display_name();

--
-- Name: psychologist_preferences trigger_user_preferences_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_user_preferences_audit AFTER INSERT OR UPDATE ON public.psychologist_preferences FOR EACH ROW EXECUTE FUNCTION public.handle_user_preferences_audit();

--
-- Name: psychologist_financial_entries validate_entry_category; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER validate_entry_category BEFORE INSERT OR UPDATE ON public.psychologist_financial_entries FOR EACH ROW EXECUTE FUNCTION public.validate_financial_entry_category();

--
-- Name: assistant_invites assistant_invites_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_invites
    ADD CONSTRAINT assistant_invites_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES auth.users(id) ON DELETE CASCADE;

--
-- Name: availability_exceptions availability_exceptions_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_exceptions
    ADD CONSTRAINT availability_exceptions_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: busy_slots busy_slots_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.busy_slots
    ADD CONSTRAINT busy_slots_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: calendar_change_log calendar_change_log_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_change_log
    ADD CONSTRAINT calendar_change_log_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: calendar_event_series_exceptions calendar_event_series_exceptions_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_event_series_exceptions
    ADD CONSTRAINT calendar_event_series_exceptions_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.calendar_event_series(id) ON DELETE CASCADE;

--
-- Name: calendar_event_series calendar_event_series_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_event_series
    ADD CONSTRAINT calendar_event_series_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: calendar_events calendar_events_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: calendar_events calendar_events_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.calendar_event_series(id) ON DELETE CASCADE;

--
-- Name: psychologist_notes clinical_notes_psychologist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_notes
    ADD CONSTRAINT clinical_notes_psychologist_client_id_fkey FOREIGN KEY (psychologist_client_id) REFERENCES public.psychologist_patients(id) ON DELETE SET NULL;

--
-- Name: psychologist_notes clinical_notes_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_notes
    ADD CONSTRAINT clinical_notes_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_notes clinical_notes_related_evolution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_notes
    ADD CONSTRAINT clinical_notes_related_evolution_id_fkey FOREIGN KEY (parent_note_id) REFERENCES public.psychologist_notes(id) ON DELETE SET NULL;

--
-- Name: clinical_session_details clinical_session_details_calendar_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_session_details
    ADD CONSTRAINT clinical_session_details_calendar_event_id_fkey FOREIGN KEY (calendar_event_id) REFERENCES public.calendar_events(id) ON DELETE CASCADE;

--
-- Name: clinical_session_details clinical_session_details_clinical_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_session_details
    ADD CONSTRAINT clinical_session_details_clinical_session_id_fkey FOREIGN KEY (clinical_session_id) REFERENCES public.psychologist_clinical_sessions(id) ON DELETE SET NULL;

--
-- Name: clinical_session_details clinical_session_details_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_session_details
    ADD CONSTRAINT clinical_session_details_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.user_patients(id) ON DELETE CASCADE;

--
-- Name: clinical_session_details clinical_session_details_psychologist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_session_details
    ADD CONSTRAINT clinical_session_details_psychologist_client_id_fkey FOREIGN KEY (psychologist_client_id) REFERENCES public.psychologist_patients(id) ON DELETE SET NULL;

--
-- Name: clinical_session_details clinical_session_details_psychologist_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_session_details
    ADD CONSTRAINT clinical_session_details_psychologist_service_id_fkey FOREIGN KEY (psychologist_service_id) REFERENCES public.psychologist_services(id) ON DELETE SET NULL;

--
-- Name: clinical_session_details clinical_session_details_session_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_session_details
    ADD CONSTRAINT clinical_session_details_session_type_id_fkey FOREIGN KEY (session_type_id) REFERENCES public.session_types(id) ON DELETE SET NULL;

--
-- Name: psychologist_clinical_sessions clinical_sessions_default_charge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_clinical_sessions
    ADD CONSTRAINT clinical_sessions_default_charge_id_fkey FOREIGN KEY (default_charge_id) REFERENCES public.psychologist_patient_charges(id) ON DELETE SET NULL;

--
-- Name: psychologist_clinical_sessions clinical_sessions_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_clinical_sessions
    ADD CONSTRAINT clinical_sessions_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.public_locations(id) ON DELETE SET NULL;

--
-- Name: psychologist_clinical_sessions clinical_sessions_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_clinical_sessions
    ADD CONSTRAINT clinical_sessions_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.psychologist_notes(id);

--
-- Name: psychologist_clinical_sessions clinical_sessions_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_clinical_sessions
    ADD CONSTRAINT clinical_sessions_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_clinical_sessions clinical_sessions_psychologist_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_clinical_sessions
    ADD CONSTRAINT clinical_sessions_psychologist_patient_id_fkey FOREIGN KEY (psychologist_patient_id) REFERENCES public.psychologist_patients(id) ON DELETE CASCADE;

--
-- Name: psychologist_clinical_sessions clinical_sessions_psychologist_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_clinical_sessions
    ADD CONSTRAINT clinical_sessions_psychologist_service_id_fkey FOREIGN KEY (psychologist_service_id) REFERENCES public.psychologist_services(id) ON DELETE SET NULL;

--
-- Name: generated_documents generated_documents_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_documents
    ADD CONSTRAINT generated_documents_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.psychologist_patients(id);

--
-- Name: generated_documents generated_documents_psychologist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_documents
    ADD CONSTRAINT generated_documents_psychologist_client_id_fkey FOREIGN KEY (psychologist_client_id) REFERENCES public.psychologist_patients(id) ON DELETE SET NULL;

--
-- Name: generated_documents generated_documents_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_documents
    ADD CONSTRAINT generated_documents_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: generated_documents generated_documents_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_documents
    ADD CONSTRAINT generated_documents_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.catalog_document_templates(id);

--
-- Name: google_calendar_connections google_calendar_connections_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_calendar_connections
    ADD CONSTRAINT google_calendar_connections_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: google_sync_idempotency google_sync_idempotency_calendar_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_idempotency
    ADD CONSTRAINT google_sync_idempotency_calendar_event_id_fkey FOREIGN KEY (calendar_event_id) REFERENCES public.calendar_events(id) ON DELETE SET NULL;

--
-- Name: google_sync_idempotency google_sync_idempotency_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_idempotency
    ADD CONSTRAINT google_sync_idempotency_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: google_sync_inbound_coalesce google_sync_inbound_coalesce_connection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_inbound_coalesce
    ADD CONSTRAINT google_sync_inbound_coalesce_connection_id_fkey FOREIGN KEY (connection_id) REFERENCES public.google_calendar_connections(id) ON DELETE CASCADE;

--
-- Name: google_sync_logs google_sync_logs_calendar_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_logs
    ADD CONSTRAINT google_sync_logs_calendar_event_id_fkey FOREIGN KEY (calendar_event_id) REFERENCES public.calendar_events(id) ON DELETE SET NULL;

--
-- Name: google_sync_logs google_sync_logs_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_logs
    ADD CONSTRAINT google_sync_logs_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: google_sync_logs google_sync_logs_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_logs
    ADD CONSTRAINT google_sync_logs_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.calendar_event_series(id) ON DELETE SET NULL;

--
-- Name: public_linktree_links linktree_links_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_linktree_links
    ADD CONSTRAINT linktree_links_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: public_client_checkout_intents marketplace_payment_intents_charge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_client_checkout_intents
    ADD CONSTRAINT marketplace_payment_intents_charge_id_fkey FOREIGN KEY (charge_id) REFERENCES public.psychologist_patient_charges(id) ON DELETE SET NULL;

--
-- Name: public_client_checkout_intents marketplace_payment_intents_psychologist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_client_checkout_intents
    ADD CONSTRAINT marketplace_payment_intents_psychologist_client_id_fkey FOREIGN KEY (psychologist_patient_id) REFERENCES public.psychologist_patients(id) ON DELETE SET NULL;

--
-- Name: public_client_checkout_intents marketplace_payment_intents_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_client_checkout_intents
    ADD CONSTRAINT marketplace_payment_intents_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE RESTRICT;

--
-- Name: public_client_checkout_intents marketplace_payment_intents_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_client_checkout_intents
    ADD CONSTRAINT marketplace_payment_intents_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.psychologist_clinical_sessions(id) ON DELETE SET NULL;

--
-- Name: psychologist_patient_activities patient_activity_assignments_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_activities
    ADD CONSTRAINT patient_activity_assignments_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.catalog_clinical_activities(id);

--
-- Name: psychologist_patient_activities patient_activity_assignments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_activities
    ADD CONSTRAINT patient_activity_assignments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user_psychologists(id);

--
-- Name: psychologist_patient_activities patient_activity_assignments_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_activities
    ADD CONSTRAINT patient_activity_assignments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.psychologist_patients(id);

--
-- Name: psychologist_patient_activities patient_activity_assignments_psychologist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_activities
    ADD CONSTRAINT patient_activity_assignments_psychologist_client_id_fkey FOREIGN KEY (psychologist_client_id) REFERENCES public.psychologist_patients(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_activities patient_activity_assignments_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_activities
    ADD CONSTRAINT patient_activity_assignments_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_activities patient_activity_assignments_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_activities
    ADD CONSTRAINT patient_activity_assignments_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user_psychologists(id);

--
-- Name: psychologist_patient_emergency_contacts patient_emergency_contacts_psychologist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_emergency_contacts
    ADD CONSTRAINT patient_emergency_contacts_psychologist_client_id_fkey FOREIGN KEY (psychologist_patient_id) REFERENCES public.psychologist_patients(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_assessments patient_tests_clinical_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_assessments
    ADD CONSTRAINT patient_tests_clinical_note_id_fkey FOREIGN KEY (clinical_note_id) REFERENCES public.psychologist_notes(id);

--
-- Name: psychologist_patient_assessments patient_tests_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_assessments
    ADD CONSTRAINT patient_tests_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user_psychologists(id);
