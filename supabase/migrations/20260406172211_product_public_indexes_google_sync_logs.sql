-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:11Z

SET check_function_bodies = false;

--
-- Name: idx_google_sync_logs_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_logs_psychologist_id ON public.google_sync_logs USING btree (psychologist_id);

--
-- Name: idx_google_sync_logs_series_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_logs_series_id ON public.google_sync_logs USING btree (series_id);

--
-- Name: idx_google_sync_worker_metrics_queue_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_worker_metrics_queue_name ON public.google_sync_worker_metrics USING btree (queue_name, recorded_at DESC);

--
-- Name: idx_google_sync_worker_metrics_recorded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_worker_metrics_recorded_at ON public.google_sync_worker_metrics USING btree (recorded_at DESC);

--
-- Name: idx_marketplace_payment_intents_charge; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_marketplace_payment_intents_charge ON public.public_client_checkout_intents USING btree (charge_id);

--
-- Name: idx_marketplace_payment_intents_psychologist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_marketplace_payment_intents_psychologist ON public.public_client_checkout_intents USING btree (psychologist_id);

--
-- Name: idx_onboarding_state_completion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_onboarding_state_completion ON public.psychologist_onboarding_state USING btree (onboarding_completed_at) WHERE (onboarding_completed_at IS NULL);

--
-- Name: idx_onboarding_state_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_onboarding_state_payment ON public.psychologist_onboarding_state USING btree (payment_step_completed) WHERE (payment_step_completed = false);

--
-- Name: idx_patient_emergency_contacts_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patient_emergency_contacts_created_by ON public.psychologist_patient_emergency_contacts USING btree (created_by);

--
-- Name: idx_patient_emergency_contacts_psychologist_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patient_emergency_contacts_psychologist_client_id ON public.psychologist_patient_emergency_contacts USING btree (psychologist_patient_id);

--
-- Name: idx_patient_emergency_contacts_updated_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patient_emergency_contacts_updated_by ON public.psychologist_patient_emergency_contacts USING btree (updated_by);

--
-- Name: idx_patients_full_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_patients_full_name ON public.user_patients USING btree (full_name);

--
-- Name: idx_psych_clinical_sessions_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_clinical_sessions_note_id ON public.psychologist_clinical_sessions USING btree (note_id);

--
-- Name: idx_psych_patient_activities_activity_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_patient_activities_activity_id ON public.psychologist_patient_activities USING btree (activity_id);

--
-- Name: idx_psych_patient_activities_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_patient_activities_patient_id ON public.psychologist_patient_activities USING btree (patient_id);

--
-- Name: idx_psych_patient_assessments_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_patient_assessments_patient_id ON public.psychologist_patient_assessments USING btree (patient_id);

--
-- Name: idx_psych_patient_guard_doc_guardian_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_patient_guard_doc_guardian_id ON public.psychologist_patient_guardian_documents USING btree (guardian_id);

--
-- Name: idx_psych_patient_guard_doc_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_patient_guard_doc_patient_id ON public.psychologist_patient_guardian_documents USING btree (patient_id);

--
-- Name: idx_psych_patient_guard_doc_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_patient_guard_doc_psychologist_id ON public.psychologist_patient_guardian_documents USING btree (psychologist_id);

--
-- Name: idx_psych_patient_med_items_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_patient_med_items_psychologist_id ON public.psychologist_patient_medical_items USING btree (psychologist_id);

--
-- Name: idx_psych_patient_med_items_therapist_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psych_patient_med_items_therapist_client_id ON public.psychologist_patient_medical_items USING btree (psychologist_patient_id);

--
-- Name: idx_psychologist_assistants_assistant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_assistants_assistant_id ON public.psychologist_assistants USING btree (assistant_id);

--
-- Name: idx_psychologist_client_services_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_client_services_psychologist_id ON public.psychologist_patient_services USING btree (psychologist_id);

--
-- Name: idx_psychologist_clients_birthdays; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_clients_birthdays ON public.psychologist_patients USING btree (psychologist_id, status) WHERE ((manual_date_of_birth IS NOT NULL) OR (synced_date_of_birth IS NOT NULL));

--
-- Name: INDEX idx_psychologist_clients_birthdays; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_psychologist_clients_birthdays IS 'Composite index for birthday calendar queries. Covers psychologist_id + status with partial index on patients with birth dates.';

--
-- Name: idx_psychologist_clinical_sessions_calendar_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_clinical_sessions_calendar_event_id ON public.psychologist_clinical_sessions USING btree (calendar_event_id);

--
-- Name: idx_psychologist_clinical_sessions_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_clinical_sessions_location_id ON public.psychologist_clinical_sessions USING btree (location_id);

--
-- Name: idx_psychologist_clinical_sessions_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_clinical_sessions_psychologist_id ON public.psychologist_clinical_sessions USING btree (psychologist_id);

--
-- Name: idx_psychologist_clinical_sessions_psychologist_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_clinical_sessions_psychologist_patient_id ON public.psychologist_clinical_sessions USING btree (psychologist_patient_id);

--
-- Name: idx_psychologist_financial_entries_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_financial_entries_charge_id ON public.psychologist_financial_entries USING btree (charge_id);

--
-- Name: idx_psychologist_financial_entries_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_financial_entries_psychologist_id ON public.psychologist_financial_entries USING btree (psychologist_id);

--
-- Name: idx_psychologist_financial_entries_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_financial_entries_session_id ON public.psychologist_financial_entries USING btree (session_id);

--
-- Name: idx_psychologist_invoices_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_invoices_psychologist_id ON public.psychologist_invoices USING btree (psychologist_id);

--
-- Name: idx_psychologist_notes_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_notes_patient_id ON public.psychologist_notes USING btree (patient_id);

--
-- Name: idx_psychologist_notes_psychologist_id; Type: INDEX; Schema: public; Owner: -
--


CREATE INDEX idx_psychologist_notes_psychologist_id ON public.psychologist_notes USING btree (psychologist_id);

--
-- Name: idx_psychologist_notes_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_notes_session_id ON public.psychologist_notes USING btree (session_id);

--
-- Name: idx_psychologist_onboarding_state_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_onboarding_state_psychologist_id ON public.psychologist_onboarding_state USING btree (psychologist_id);

--
-- Name: idx_psychologist_patient_activities_psychologist_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_activities_psychologist_client_id ON public.psychologist_patient_activities USING btree (psychologist_client_id);

--
-- Name: idx_psychologist_patient_activities_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_activities_psychologist_id ON public.psychologist_patient_activities USING btree (psychologist_id);

--
-- Name: idx_psychologist_patient_assessments_psychologist_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_assessments_psychologist_client_id ON public.psychologist_patient_assessments USING btree (psychologist_client_id);

--
-- Name: idx_psychologist_patient_assessments_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_assessments_psychologist_id ON public.psychologist_patient_assessments USING btree (psychologist_id);

--
-- Name: idx_psychologist_patient_charges_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_charges_psychologist_id ON public.psychologist_patient_charges USING btree (psychologist_id);

--
-- Name: idx_psychologist_patient_charges_psychologist_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_charges_psychologist_patient_id ON public.psychologist_patient_charges USING btree (psychologist_patient_id);

--
-- Name: idx_psychologist_patient_guardians_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_guardians_patient_id ON public.psychologist_patient_guardians USING btree (patient_id);

--
-- Name: idx_psychologist_patient_guardians_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_guardians_psychologist_id ON public.psychologist_patient_guardians USING btree (psychologist_id);

--
-- Name: idx_psychologist_patient_services_psychologist_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patient_services_psychologist_patient_id ON public.psychologist_patient_services USING btree (psychologist_patient_id);

--
-- Name: idx_psychologist_patients_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_patients_patient_id ON public.psychologist_patients USING btree (patient_id);

--
-- Name: idx_psychologist_quick_notes_due_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_quick_notes_due_date ON public.psychologist_quick_notes USING btree (due_date);

--
-- Name: idx_psychologist_quick_notes_is_completed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_quick_notes_is_completed ON public.psychologist_quick_notes USING btree (is_completed);

--
-- Name: idx_psychologist_quick_notes_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_quick_notes_psychologist_id ON public.psychologist_quick_notes USING btree (psychologist_id);

--
-- Name: idx_psychologist_services_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_services_psychologist_id ON public.psychologist_services USING btree (psychologist_id);

--
-- Name: idx_psychologist_stripe_connect_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_stripe_connect_account_id ON public.psychologist_stripe_connect USING btree (stripe_account_id);

--
-- Name: idx_psychologist_subscriptions_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_subscriptions_psychologist_id ON public.psychologist_subscriptions USING btree (psychologist_id);

--
-- Name: idx_psychologist_weekly_schedules_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_weekly_schedules_location_id ON public.psychologist_weekly_schedules USING btree (location_id);

--
-- Name: idx_psychologist_weekly_schedules_psychologist_day; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_weekly_schedules_psychologist_day ON public.psychologist_weekly_schedules USING btree (psychologist_id, day_of_week);

--
-- Name: INDEX idx_psychologist_weekly_schedules_psychologist_day; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.idx_psychologist_weekly_schedules_psychologist_day IS 'Supports efficient lookup of weekly schedules by psychologist and day for onboarding checks';

--
-- Name: idx_psychologist_weekly_schedules_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psychologist_weekly_schedules_psychologist_id ON public.psychologist_weekly_schedules USING btree (psychologist_id);

--
-- Name: idx_public_client_checkout_intents_psychologist_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_public_client_checkout_intents_psychologist_patient_id ON public.public_client_checkout_intents USING btree (psychologist_patient_id);

--
-- Name: idx_public_client_checkout_intents_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_public_client_checkout_intents_session_id ON public.public_client_checkout_intents USING btree (session_id);

--
-- Name: idx_public_linktree_links_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_public_linktree_links_psychologist_id ON public.public_linktree_links USING btree (psychologist_id);

--
-- Name: idx_public_locations_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_public_locations_psychologist_id ON public.public_locations USING btree (psychologist_id);

--
-- Name: idx_security_audit_events_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_security_audit_events_action ON public.security_audit_events USING btree (action, occurred_at DESC);

--
-- Name: idx_security_audit_events_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_security_audit_events_actor ON public.security_audit_events USING btree (actor_id, occurred_at DESC);
