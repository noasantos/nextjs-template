-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:14Z

SET check_function_bodies = false;

--
-- Name: idx_security_audit_events_correlation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_security_audit_events_correlation ON public.security_audit_events USING btree (correlation_id);

--
-- Name: idx_session_billing_dead_letter_psychologist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_billing_dead_letter_psychologist ON public.session_billing_dead_letter USING btree (psychologist_id, created_at DESC);

--
-- Name: idx_session_details_clinical; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_details_clinical ON public.clinical_session_details USING btree (clinical_session_id) WHERE (clinical_session_id IS NOT NULL);

--
-- Name: idx_session_details_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_details_event ON public.clinical_session_details USING btree (calendar_event_id);

--
-- Name: idx_session_details_patient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_details_patient ON public.clinical_session_details USING btree (patient_id);

--
-- Name: idx_session_reschedule_logs_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_reschedule_logs_created_by ON public.session_reschedule_logs USING btree (created_by);

--
-- Name: idx_session_reschedule_logs_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_reschedule_logs_session_id ON public.session_reschedule_logs USING btree (session_id);

--
-- Name: idx_session_reschedule_requests_initiated_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_reschedule_requests_initiated_by ON public.session_reschedule_requests USING btree (initiated_by);

--
-- Name: idx_session_reschedule_requests_responded_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_reschedule_requests_responded_by ON public.session_reschedule_requests USING btree (responded_by);

--
-- Name: idx_session_reschedule_requests_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_session_reschedule_requests_session_id ON public.session_reschedule_requests USING btree (session_id);

--
-- Name: idx_stripe_idempotency_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stripe_idempotency_expires ON public.stripe_idempotency_log USING btree (expires_at);

--
-- Name: idx_stripe_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stripe_idempotency_key ON public.stripe_idempotency_log USING btree (idempotency_key);

--
-- Name: idx_sync_conflict_resolutions_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sync_conflict_resolutions_event_id ON public.sync_conflict_resolutions USING btree (event_id);

--
-- Name: idx_sync_conflict_resolutions_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sync_conflict_resolutions_psychologist_id ON public.sync_conflict_resolutions USING btree (psychologist_id);

--
-- Name: idx_unified_family; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_unified_family ON public.unified_events USING btree (event_family, "timestamp" DESC);

--
-- Name: idx_unified_metadata; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_unified_metadata ON public.unified_events USING gin (metadata jsonb_path_ops);

--
-- Name: idx_unified_service; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_unified_service ON public.unified_events USING btree (service, component, "timestamp" DESC);

--
-- Name: idx_unified_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_unified_time ON public.unified_events USING btree ("timestamp" DESC);

--
-- Name: idx_webhook_audit_received_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_webhook_audit_received_at ON public.webhook_audit_log USING btree (received_at);

--
-- Name: idx_webhook_audit_source_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_webhook_audit_source_event ON public.webhook_audit_log USING btree (source, event_id);

--
-- Name: psychologist_assistants_active_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX psychologist_assistants_active_unique_idx ON public.psychologist_assistants USING btree (psychologist_id, assistant_id) WHERE (revoked_at IS NULL);

--
-- Name: psychologist_notes_ai_child_unique_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX psychologist_notes_ai_child_unique_idx ON public.psychologist_notes USING btree (parent_note_id) WHERE (parent_note_id IS NOT NULL);

--
-- Name: psychologist_patients_invite_token_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX psychologist_patients_invite_token_key ON public.psychologist_patients USING btree (invite_token) WHERE (invite_token IS NOT NULL);

--
-- Name: psychologist_services_catalog_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX psychologist_services_catalog_id_idx ON public.psychologist_services USING btree (catalog_id);

--
-- Name: psychologist_session_cancellation_policy_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX psychologist_session_cancellation_policy_active_idx ON public.psychologist_session_cancellation_policy USING btree (psychologist_id) WHERE (effective_until IS NULL);

--
-- Name: reference_values_category_value_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX reference_values_category_value_idx ON public.reference_values USING btree (category, value);

--
-- Name: uniq_calendar_events_google_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_calendar_events_google_event_id ON public.calendar_events USING btree (psychologist_id, google_event_id) WHERE (google_event_id IS NOT NULL);

--
-- Name: uniq_calendar_events_google_recurring_instance; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_calendar_events_google_recurring_instance ON public.calendar_events USING btree (psychologist_id, google_recurring_event_id, google_original_start_time) WHERE ((google_recurring_event_id IS NOT NULL) AND (google_original_start_time IS NOT NULL));

--
-- Name: ux_psychologist_client_charges_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_psychologist_client_charges_session_id ON public.psychologist_patient_charges USING btree (session_id) WHERE (session_id IS NOT NULL);

--
-- Name: ux_session_billing_dead_letter_open; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_session_billing_dead_letter_open ON public.session_billing_dead_letter USING btree (session_id) WHERE (resolved_at IS NULL);

--
-- Name: clinical_session_details clinical_session_details_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER clinical_session_details_updated_at BEFORE UPDATE ON public.clinical_session_details FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');

--
-- Name: psychologist_clinical_sessions on_session_completed_stats; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_session_completed_stats AFTER UPDATE ON public.psychologist_clinical_sessions FOR EACH ROW WHEN (((new.status = 'completed'::text) AND ((old.status IS NULL) OR (old.status <> 'completed'::text)))) EXECUTE FUNCTION public.update_patient_session_stats();

--
-- Name: psychologist_clinical_sessions on_session_created_charge; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_session_created_charge AFTER INSERT ON public.psychologist_clinical_sessions FOR EACH ROW EXECUTE FUNCTION public.handle_new_session_charge();

--
-- Name: psychologist_clinical_sessions on_session_updated_charge; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_session_updated_charge AFTER UPDATE ON public.psychologist_clinical_sessions FOR EACH ROW EXECUTE FUNCTION public.handle_session_update_charge();

--
-- Name: session_types session_types_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER session_types_updated_at BEFORE UPDATE ON public.session_types FOR EACH ROW EXECUTE FUNCTION extensions.moddatetime('updated_at');

--
-- Name: public_linktree_links sync_marketplace_linktree_links; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_marketplace_linktree_links AFTER INSERT OR DELETE OR UPDATE ON public.public_linktree_links FOR EACH ROW EXECUTE FUNCTION public.sync_marketplace_linktree_link();

--
-- Name: public_locations sync_marketplace_locations; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_marketplace_locations AFTER INSERT OR DELETE OR UPDATE ON public.public_locations FOR EACH ROW EXECUTE FUNCTION public.sync_marketplace_location();

--
-- Name: public_profiles sync_marketplace_profile; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_marketplace_profile AFTER INSERT OR DELETE OR UPDATE ON public.public_profiles FOR EACH ROW EXECUTE FUNCTION public.sync_marketplace_profile();

--
-- Name: public_profiles sync_username_to_psychologist_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_username_to_psychologist_trigger AFTER UPDATE OF slug ON public.public_profiles FOR EACH ROW WHEN ((new.slug IS DISTINCT FROM old.slug)) EXECUTE FUNCTION public.sync_username_to_psychologist();

--
-- Name: psychologist_assistants tr_audit_psychologist_assistants; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_audit_psychologist_assistants AFTER INSERT OR DELETE OR UPDATE ON public.psychologist_assistants FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

--
-- Name: TRIGGER tr_audit_psychologist_assistants ON psychologist_assistants; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER tr_audit_psychologist_assistants ON public.psychologist_assistants IS 'Audit logging for access control changes (who can see whose data)';

--
-- Name: psychologist_clinical_sessions tr_audit_psychologist_clinical_sessions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_audit_psychologist_clinical_sessions AFTER INSERT OR DELETE OR UPDATE ON public.psychologist_clinical_sessions FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

--
-- Name: TRIGGER tr_audit_psychologist_clinical_sessions ON psychologist_clinical_sessions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER tr_audit_psychologist_clinical_sessions ON public.psychologist_clinical_sessions IS 'Audit logging for appointment history and scheduling changes';

--
-- Name: psychologist_financial_entries tr_audit_psychologist_financial_entries; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_audit_psychologist_financial_entries AFTER INSERT OR DELETE OR UPDATE ON public.psychologist_financial_entries FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

--
-- Name: TRIGGER tr_audit_psychologist_financial_entries ON psychologist_financial_entries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER tr_audit_psychologist_financial_entries ON public.psychologist_financial_entries IS 'Audit logging for billing and payment history';

--
-- Name: psychologist_notes tr_audit_psychologist_notes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_audit_psychologist_notes AFTER INSERT OR DELETE OR UPDATE ON public.psychologist_notes FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

--
-- Name: TRIGGER tr_audit_psychologist_notes ON psychologist_notes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER tr_audit_psychologist_notes ON public.psychologist_notes IS 'Audit logging for clinical notes and patient history (high sensitivity)';

--
-- Name: psychologist_patient_charges tr_audit_psychologist_patient_charges; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_audit_psychologist_patient_charges AFTER INSERT OR DELETE OR UPDATE ON public.psychologist_patient_charges FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

--
-- Name: TRIGGER tr_audit_psychologist_patient_charges ON psychologist_patient_charges; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER tr_audit_psychologist_patient_charges ON public.psychologist_patient_charges IS 'Audit logging for patient charges';

--
-- Name: psychologist_patients tr_audit_psychologist_patients; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_audit_psychologist_patients AFTER INSERT OR DELETE OR UPDATE ON public.psychologist_patients FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

--
-- Name: TRIGGER tr_audit_psychologist_patients ON psychologist_patients; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TRIGGER tr_audit_psychologist_patients ON public.psychologist_patients IS 'Audit logging for patient demographic and contact data';

--
-- Name: psychologist_session_cancellation_policy tr_close_previous_cancellation_policy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER tr_close_previous_cancellation_policy BEFORE INSERT ON public.psychologist_session_cancellation_policy FOR EACH ROW EXECUTE FUNCTION public.fn_close_previous_cancellation_policy();

--
-- Name: calendar_events trg_calendar_event_busy_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_calendar_event_busy_sync AFTER INSERT OR DELETE OR UPDATE ON public.calendar_events FOR EACH ROW EXECUTE FUNCTION public.sync_calendar_event_to_busy_slots();

--
-- Name: calendar_event_series trg_calendar_event_series_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_calendar_event_series_updated_at BEFORE UPDATE ON public.calendar_event_series FOR EACH ROW EXECUTE FUNCTION public.update_calendar_updated_at();

--
-- Name: calendar_events trg_calendar_events_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_calendar_events_updated_at BEFORE UPDATE ON public.calendar_events FOR EACH ROW EXECUTE FUNCTION public.update_calendar_updated_at();

--
-- Name: psychologist_clinical_sessions trg_clinical_session_busy_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_clinical_session_busy_sync AFTER INSERT OR DELETE OR UPDATE ON public.psychologist_clinical_sessions FOR EACH ROW EXECUTE FUNCTION public.sync_clinical_session_to_busy_slots();

--
-- Name: clinical_session_details trg_clinical_session_details_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_clinical_session_details_updated_at BEFORE UPDATE ON public.clinical_session_details FOR EACH ROW EXECUTE FUNCTION public.update_calendar_updated_at();

--
-- Name: psychologist_session_cancellation_policy trg_close_previous_cancellation_policy; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_close_previous_cancellation_policy AFTER INSERT ON public.psychologist_session_cancellation_policy FOR EACH ROW EXECUTE FUNCTION public.tr_close_previous_cancellation_policy();

--
-- Name: public_linktree_links trg_enforce_linktree_active_limit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_linktree_active_limit BEFORE INSERT OR UPDATE OF is_active ON public.public_linktree_links FOR EACH ROW EXECUTE FUNCTION public.enforce_linktree_active_limit();

--
-- Name: google_calendar_connections trg_google_calendar_connections_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_google_calendar_connections_updated_at BEFORE UPDATE ON public.google_calendar_connections FOR EACH ROW EXECUTE FUNCTION public.update_calendar_updated_at();

--
-- Name: calendar_events trg_stamp_calendar_event_sync_origin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_stamp_calendar_event_sync_origin BEFORE INSERT OR UPDATE ON public.calendar_events FOR EACH ROW EXECUTE FUNCTION public.stamp_calendar_event_sync_origin();

--
-- Name: calendar_events trg_sync_calendar_to_session; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_calendar_to_session AFTER UPDATE ON public.calendar_events FOR EACH ROW WHEN (((old.start_datetime IS DISTINCT FROM new.start_datetime) OR (old.end_datetime IS DISTINCT FROM new.end_datetime))) EXECUTE FUNCTION public.tr_sync_calendar_to_session();

--
-- Name: user_psychologists trg_sync_onboarding_completed; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_onboarding_completed BEFORE UPDATE OF subscription_status ON public.user_psychologists FOR EACH ROW EXECUTE FUNCTION public.sync_onboarding_completed_with_essential();

--
-- Name: user_psychologists trg_sync_payment_step; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_payment_step AFTER UPDATE OF subscription_status ON public.user_psychologists FOR EACH ROW WHEN ((new.subscription_status = ANY (ARRAY['active'::text, 'trialing'::text]))) EXECUTE FUNCTION public.sync_payment_step_with_subscription();
