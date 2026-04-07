-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:08Z

SET check_function_bodies = false;

--
-- Name: reference_values reference_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reference_values
    ADD CONSTRAINT reference_values_pkey PRIMARY KEY (id);

--
-- Name: security_audit_events security_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.security_audit_events
    ADD CONSTRAINT security_audit_events_pkey PRIMARY KEY (id);

--
-- Name: session_billing_dead_letter session_billing_dead_letter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_billing_dead_letter
    ADD CONSTRAINT session_billing_dead_letter_pkey PRIMARY KEY (id);

--
-- Name: session_reschedule_logs session_reschedule_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_reschedule_logs
    ADD CONSTRAINT session_reschedule_logs_pkey PRIMARY KEY (id);

--
-- Name: session_reschedule_requests session_reschedule_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_reschedule_requests
    ADD CONSTRAINT session_reschedule_requests_pkey PRIMARY KEY (id);

--
-- Name: session_types session_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_types
    ADD CONSTRAINT session_types_code_key UNIQUE (code);

--
-- Name: session_types session_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.session_types
    ADD CONSTRAINT session_types_pkey PRIMARY KEY (id);

--
-- Name: stripe_idempotency_log stripe_idempotency_log_idempotency_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_idempotency_log
    ADD CONSTRAINT stripe_idempotency_log_idempotency_key_key UNIQUE (idempotency_key);

--
-- Name: stripe_idempotency_log stripe_idempotency_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_idempotency_log
    ADD CONSTRAINT stripe_idempotency_log_pkey PRIMARY KEY (id);

--
-- Name: subscription_plans stripe_price_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscription_plans
    ADD CONSTRAINT stripe_price_plans_pkey PRIMARY KEY (id);

--
-- Name: stripe_webhook_events stripe_webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_webhook_events
    ADD CONSTRAINT stripe_webhook_events_pkey PRIMARY KEY (id);

--
-- Name: stripe_webhook_events stripe_webhook_events_stripe_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stripe_webhook_events
    ADD CONSTRAINT stripe_webhook_events_stripe_event_id_key UNIQUE (stripe_event_id);

--
-- Name: sync_conflict_resolutions sync_conflict_resolutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_conflict_resolutions
    ADD CONSTRAINT sync_conflict_resolutions_pkey PRIMARY KEY (id);

--
-- Name: sync_locks sync_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_locks
    ADD CONSTRAINT sync_locks_pkey PRIMARY KEY (lock_key);

--
-- Name: unified_events unified_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unified_events
    ADD CONSTRAINT unified_events_pkey PRIMARY KEY (id);

--
-- Name: clinical_session_details unique_event_session; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_session_details
    ADD CONSTRAINT unique_event_session UNIQUE (calendar_event_id);

--
-- Name: google_calendar_connections unique_psychologist_google_connection; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_calendar_connections
    ADD CONSTRAINT unique_psychologist_google_connection UNIQUE (psychologist_id);

--
-- Name: calendar_event_series_exceptions unique_series_exception; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_event_series_exceptions
    ADD CONSTRAINT unique_series_exception UNIQUE (series_id, original_date);

--
-- Name: busy_slots unique_source; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.busy_slots
    ADD CONSTRAINT unique_source UNIQUE (source_type, source_id);

--
-- Name: psychologist_preferences_audit_log user_preferences_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_preferences_audit_log
    ADD CONSTRAINT user_preferences_audit_log_pkey PRIMARY KEY (id);

--
-- Name: psychologist_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (id);

--
-- Name: psychologist_preferences user_preferences_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_preferences
    ADD CONSTRAINT user_preferences_user_id_key UNIQUE (user_id);

--
-- Name: webhook_audit_log webhook_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_audit_log
    ADD CONSTRAINT webhook_audit_log_pkey PRIMARY KEY (id);

--
-- Name: webhook_events webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events
    ADD CONSTRAINT webhook_events_pkey PRIMARY KEY (event_id);

--
-- Name: assistant_invites_invited_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assistant_invites_invited_email_idx ON public.assistant_invites USING btree (invited_email);

--
-- Name: assistant_invites_pending_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX assistant_invites_pending_idx ON public.assistant_invites USING btree (invited_email, expires_at) WHERE ((accepted_at IS NULL) AND (revoked_at IS NULL));

--
-- Name: idx_account_deletion_requests_correlation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_deletion_requests_correlation ON public.account_deletion_requests USING btree (correlation_id);

--
-- Name: idx_account_deletion_requests_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_deletion_requests_user ON public.account_deletion_requests USING btree (user_id, requested_at DESC);

--
-- Name: idx_assistant_invites_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assistant_invites_psychologist_id ON public.assistant_invites USING btree (psychologist_id);

--
-- Name: idx_availability_exceptions_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_availability_exceptions_psychologist_id ON public.availability_exceptions USING btree (psychologist_id);

--
-- Name: idx_busy_slots_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_busy_slots_psychologist_id ON public.busy_slots USING btree (psychologist_id);

--
-- Name: idx_busy_slots_psychologist_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_busy_slots_psychologist_range ON public.busy_slots USING gist (psychologist_id, slot_range);

--
-- Name: idx_busy_slots_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_busy_slots_source ON public.busy_slots USING btree (source_type, source_id);

--
-- Name: idx_calendar_change_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_calendar_change_event ON public.calendar_change_log USING btree (google_event_id, modification_hash);

--
-- Name: idx_calendar_change_psych; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_calendar_change_psych ON public.calendar_change_log USING btree (psychologist_id);

--
-- Name: idx_calendar_event_series_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_calendar_event_series_psychologist_id ON public.calendar_event_series USING btree (psychologist_id);

--
-- Name: idx_calendar_events_google_recurring_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_calendar_events_google_recurring_lookup ON public.calendar_events USING btree (psychologist_id, google_recurring_event_id, google_original_start_time);

--
-- Name: idx_calendar_events_series_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_calendar_events_series_start ON public.calendar_events USING btree (series_id, start_datetime) WHERE (series_id IS NOT NULL);

--
-- Name: idx_calendar_holidays_year_state_city_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_calendar_holidays_year_state_city_date ON public.calendar_holidays USING btree (year, state, city, date);

--
-- Name: idx_clinical_session_details_billing_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clinical_session_details_billing_queue ON public.clinical_session_details USING btree (billing_status, billing_next_attempt_at, clinical_session_id) WHERE (clinical_session_id IS NOT NULL);

--
-- Name: idx_clinical_session_details_clinical_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clinical_session_details_clinical_session_id ON public.clinical_session_details USING btree (clinical_session_id);

--
-- Name: idx_clinical_session_details_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clinical_session_details_patient_id ON public.clinical_session_details USING btree (patient_id);

--
-- Name: idx_clinical_session_details_psychologist_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clinical_session_details_psychologist_client_id ON public.clinical_session_details USING btree (psychologist_client_id);

--
-- Name: idx_clinical_session_details_psychologist_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clinical_session_details_psychologist_service_id ON public.clinical_session_details USING btree (psychologist_service_id);

--
-- Name: idx_clinical_session_details_session_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clinical_session_details_session_type_id ON public.clinical_session_details USING btree (session_type_id);

--
-- Name: idx_clinical_sessions_psychologist_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clinical_sessions_psychologist_service_id ON public.psychologist_clinical_sessions USING btree (psychologist_service_id);

--
-- Name: idx_clinical_sessions_start_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_clinical_sessions_start_time ON public.psychologist_clinical_sessions USING btree (start_time);

--
-- Name: idx_encryption_audit_operation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_encryption_audit_operation ON public.encryption_audit_log USING btree (operation, attempted_at);

--
-- Name: idx_encryption_audit_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_encryption_audit_user ON public.encryption_audit_log USING btree (caller_user_id);

--
-- Name: idx_generated_documents_patient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_generated_documents_patient_id ON public.generated_documents USING btree (patient_id);

--
-- Name: idx_generated_documents_psychologist_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_generated_documents_psychologist_client_id ON public.generated_documents USING btree (psychologist_client_id);

--
-- Name: idx_generated_documents_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_generated_documents_psychologist_id ON public.generated_documents USING btree (psychologist_id);

--
-- Name: idx_generated_documents_template_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_generated_documents_template_id ON public.generated_documents USING btree (template_id);

--
-- Name: idx_google_calendar_connections_watch_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_calendar_connections_watch_expires_at ON public.google_calendar_connections USING btree (watch_expires_at) WHERE (is_connected = true);

--
-- Name: idx_google_sync_idempotency_calendar_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_idempotency_calendar_event_id ON public.google_sync_idempotency USING btree (calendar_event_id);

--
-- Name: idx_google_sync_idempotency_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_idempotency_expires_at ON public.google_sync_idempotency USING btree (expires_at);

--
-- Name: idx_google_sync_idempotency_psychologist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_idempotency_psychologist_id ON public.google_sync_idempotency USING btree (psychologist_id);

--
-- Name: idx_google_sync_idempotency_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_idempotency_status ON public.google_sync_idempotency USING btree (status);

--
-- Name: idx_google_sync_logs_calendar_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_google_sync_logs_calendar_event_id ON public.google_sync_logs USING btree (calendar_event_id);
