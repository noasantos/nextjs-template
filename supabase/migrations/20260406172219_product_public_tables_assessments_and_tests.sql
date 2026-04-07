-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:19Z

SET check_function_bodies = false;

--
-- Name: psychologist_patient_assessments patient_tests_psychologist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_assessments
    ADD CONSTRAINT patient_tests_psychologist_client_id_fkey FOREIGN KEY (psychologist_client_id) REFERENCES public.psychologist_patients(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_assessments patient_tests_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_assessments
    ADD CONSTRAINT patient_tests_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_assessments patient_tests_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_assessments
    ADD CONSTRAINT patient_tests_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.user_psychologists(id);

--
-- Name: psychologist_assistants psychologist_assistants_assistant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_assistants
    ADD CONSTRAINT psychologist_assistants_assistant_id_fkey FOREIGN KEY (assistant_id) REFERENCES auth.users(id) ON DELETE CASCADE;

--
-- Name: psychologist_assistants psychologist_assistants_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_assistants
    ADD CONSTRAINT psychologist_assistants_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES auth.users(id) ON DELETE CASCADE;

--
-- Name: psychologist_weekly_schedules psychologist_availability_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_weekly_schedules
    ADD CONSTRAINT psychologist_availability_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.public_locations(id) ON DELETE SET NULL;

--
-- Name: psychologist_weekly_schedules psychologist_availability_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_weekly_schedules
    ADD CONSTRAINT psychologist_availability_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_charges psychologist_client_charges_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_charges
    ADD CONSTRAINT psychologist_client_charges_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_charges psychologist_client_charges_psychologist_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_charges
    ADD CONSTRAINT psychologist_client_charges_psychologist_patient_id_fkey FOREIGN KEY (psychologist_patient_id) REFERENCES public.psychologist_patients(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_charges psychologist_client_charges_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_charges
    ADD CONSTRAINT psychologist_client_charges_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.psychologist_clinical_sessions(id) ON DELETE SET NULL;

--
-- Name: psychologist_patient_services psychologist_client_services_psychologist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_services
    ADD CONSTRAINT psychologist_client_services_psychologist_client_id_fkey FOREIGN KEY (psychologist_patient_id) REFERENCES public.psychologist_patients(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_services psychologist_client_services_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_services
    ADD CONSTRAINT psychologist_client_services_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patients psychologist_clients_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patients
    ADD CONSTRAINT psychologist_clients_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.user_patients(id) ON DELETE SET NULL;

--
-- Name: psychologist_patients psychologist_clients_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patients
    ADD CONSTRAINT psychologist_clients_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_clinical_sessions psychologist_clinical_sessions_calendar_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_clinical_sessions
    ADD CONSTRAINT psychologist_clinical_sessions_calendar_event_id_fkey FOREIGN KEY (calendar_event_id) REFERENCES public.calendar_events(id) ON DELETE CASCADE;

--
-- Name: psychologist_financial_entries psychologist_financial_entries_billing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_financial_entries
    ADD CONSTRAINT psychologist_financial_entries_billing_id_fkey FOREIGN KEY (billing_id) REFERENCES public.psychologist_patient_charges(id);

--
-- Name: psychologist_financial_entries psychologist_financial_entries_charge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_financial_entries
    ADD CONSTRAINT psychologist_financial_entries_charge_id_fkey FOREIGN KEY (charge_id) REFERENCES public.psychologist_patient_charges(id) ON DELETE SET NULL;

--
-- Name: psychologist_financial_entries psychologist_financial_entries_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_financial_entries
    ADD CONSTRAINT psychologist_financial_entries_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_financial_entries psychologist_financial_entries_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_financial_entries
    ADD CONSTRAINT psychologist_financial_entries_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.psychologist_clinical_sessions(id) ON DELETE SET NULL;

--
-- Name: psychologist_financial_entries psychologist_financial_entries_transaction_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_financial_entries
    ADD CONSTRAINT psychologist_financial_entries_transaction_category_id_fkey FOREIGN KEY (transaction_category_id) REFERENCES public.reference_values(id) ON DELETE SET NULL;

--
-- Name: CONSTRAINT psychologist_financial_entries_transaction_category_id_fkey ON psychologist_financial_entries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT psychologist_financial_entries_transaction_category_id_fkey ON public.psychologist_financial_entries IS 'Links financial entry to transaction category in reference_values table';

--
-- Name: psychologist_invoices psychologist_invoices_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_invoices
    ADD CONSTRAINT psychologist_invoices_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_notes psychologist_notes_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_notes
    ADD CONSTRAINT psychologist_notes_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.psychologist_patients(id) ON DELETE SET NULL;

--
-- Name: psychologist_notes psychologist_notes_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_notes
    ADD CONSTRAINT psychologist_notes_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.psychologist_clinical_sessions(id) ON DELETE SET NULL;

--
-- Name: psychologist_onboarding_state psychologist_onboarding_state_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_onboarding_state
    ADD CONSTRAINT psychologist_onboarding_state_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_assessments psychologist_patient_assessments_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_assessments
    ADD CONSTRAINT psychologist_patient_assessments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.psychologist_patients(id);

--
-- Name: psychologist_patient_guardian_documents psychologist_patient_guardian_documents_guardian_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_guardian_documents
    ADD CONSTRAINT psychologist_patient_guardian_documents_guardian_id_fkey FOREIGN KEY (guardian_id) REFERENCES public.psychologist_patient_guardians(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_guardian_documents psychologist_patient_guardian_documents_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_guardian_documents
    ADD CONSTRAINT psychologist_patient_guardian_documents_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.psychologist_patients(id);

--
-- Name: psychologist_patient_guardian_documents psychologist_patient_guardian_documents_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_guardian_documents
    ADD CONSTRAINT psychologist_patient_guardian_documents_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_guardians psychologist_patient_guardians_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_guardians
    ADD CONSTRAINT psychologist_patient_guardians_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.user_patients(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_guardians psychologist_patient_guardians_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_guardians
    ADD CONSTRAINT psychologist_patient_guardians_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_medical_items psychologist_patient_medical_items_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_medical_items
    ADD CONSTRAINT psychologist_patient_medical_items_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_patient_medical_items psychologist_patient_medical_items_therapist_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_medical_items
    ADD CONSTRAINT psychologist_patient_medical_items_therapist_client_id_fkey FOREIGN KEY (psychologist_patient_id) REFERENCES public.psychologist_patients(id) ON DELETE CASCADE;

--
-- Name: psychologist_patients psychologist_patients_archived_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patients
    ADD CONSTRAINT psychologist_patients_archived_by_fkey FOREIGN KEY (archived_by) REFERENCES public.user_psychologists(id);

--
-- Name: psychologist_patients psychologist_patients_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patients
    ADD CONSTRAINT psychologist_patients_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.user_psychologists(id);

--
-- Name: psychologist_patients psychologist_patients_price_set_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patients
    ADD CONSTRAINT psychologist_patients_price_set_by_fkey FOREIGN KEY (price_set_by) REFERENCES public.user_psychologists(id);

--
-- Name: public_profiles psychologist_profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_profiles
    ADD CONSTRAINT psychologist_profiles_id_fkey FOREIGN KEY (id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_quick_notes psychologist_quick_notes_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_quick_notes
    ADD CONSTRAINT psychologist_quick_notes_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_services psychologist_services_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_services
    ADD CONSTRAINT psychologist_services_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.reference_values(id) ON DELETE SET NULL;

--
-- Name: psychologist_services psychologist_services_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_services
    ADD CONSTRAINT psychologist_services_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_session_cancellation_policy psychologist_session_cancellation_policy_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_session_cancellation_policy
    ADD CONSTRAINT psychologist_session_cancellation_policy_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_stripe_connect psychologist_stripe_connect_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_stripe_connect
    ADD CONSTRAINT psychologist_stripe_connect_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_subscriptions psychologist_subscriptions_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_subscriptions
    ADD CONSTRAINT psychologist_subscriptions_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: psychologist_subscriptions psychologist_subscriptions_therapist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_subscriptions
    ADD CONSTRAINT psychologist_subscriptions_therapist_id_fkey FOREIGN KEY (therapist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: public_locations public_locations_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_locations
    ADD CONSTRAINT public_locations_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: session_billing_dead_letter session_billing_dead_letter_psychologist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_billing_dead_letter
    ADD CONSTRAINT session_billing_dead_letter_psychologist_id_fkey FOREIGN KEY (psychologist_id) REFERENCES public.user_psychologists(id) ON DELETE CASCADE;

--
-- Name: session_billing_dead_letter session_billing_dead_letter_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_billing_dead_letter
    ADD CONSTRAINT session_billing_dead_letter_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.psychologist_clinical_sessions(id) ON DELETE CASCADE;

--
-- Name: session_reschedule_logs session_reschedule_logs_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_reschedule_logs
    ADD CONSTRAINT session_reschedule_logs_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.user_psychologists(id);

--
-- Name: session_reschedule_logs session_reschedule_logs_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_reschedule_logs
    ADD CONSTRAINT session_reschedule_logs_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.psychologist_clinical_sessions(id);

--
-- Name: session_reschedule_requests session_reschedule_requests_initiated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_reschedule_requests
    ADD CONSTRAINT session_reschedule_requests_initiated_by_fkey FOREIGN KEY (initiated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

--
-- Name: session_reschedule_requests session_reschedule_requests_responded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_reschedule_requests
    ADD CONSTRAINT session_reschedule_requests_responded_by_fkey FOREIGN KEY (responded_by) REFERENCES auth.users(id) ON DELETE SET NULL;

--
-- Name: session_reschedule_requests session_reschedule_requests_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_reschedule_requests
    ADD CONSTRAINT session_reschedule_requests_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.psychologist_clinical_sessions(id) ON DELETE CASCADE;

--
-- Name: sync_conflict_resolutions sync_conflict_resolutions_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_conflict_resolutions
    ADD CONSTRAINT sync_conflict_resolutions_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.calendar_events(id) ON DELETE SET NULL;
