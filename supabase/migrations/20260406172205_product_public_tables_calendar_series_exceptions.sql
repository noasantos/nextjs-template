-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:05Z

SET check_function_bodies = false;

--
-- Name: calendar_event_series_exceptions calendar_event_series_exceptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_event_series_exceptions
    ADD CONSTRAINT calendar_event_series_exceptions_pkey PRIMARY KEY (id);

--
-- Name: calendar_event_series calendar_event_series_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_event_series
    ADD CONSTRAINT calendar_event_series_pkey PRIMARY KEY (id);

--
-- Name: calendar_events calendar_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_pkey PRIMARY KEY (id);

--
-- Name: calendar_holidays calendar_holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_holidays
    ADD CONSTRAINT calendar_holidays_pkey PRIMARY KEY (id);

--
-- Name: calendar_holidays calendar_holidays_year_state_city_date_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_holidays
    ADD CONSTRAINT calendar_holidays_year_state_city_date_unique UNIQUE (year, state, city, date);

--
-- Name: catalog_document_templates catalog_document_templates_title_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalog_document_templates
    ADD CONSTRAINT catalog_document_templates_title_unique UNIQUE (title);

--
-- Name: CONSTRAINT catalog_document_templates_title_unique ON catalog_document_templates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON CONSTRAINT catalog_document_templates_title_unique ON public.catalog_document_templates IS 'Enables idempotent seeding of document templates using ON CONFLICT DO UPDATE';

--
-- Name: catalog_clinical_activities clinical_activities_catalog_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalog_clinical_activities
    ADD CONSTRAINT clinical_activities_catalog_code_key UNIQUE (code);

--
-- Name: catalog_clinical_activities clinical_activities_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalog_clinical_activities
    ADD CONSTRAINT clinical_activities_catalog_pkey PRIMARY KEY (id);

--
-- Name: psychologist_notes clinical_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_notes
    ADD CONSTRAINT clinical_notes_pkey PRIMARY KEY (id);

--
-- Name: clinical_session_details clinical_session_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinical_session_details
    ADD CONSTRAINT clinical_session_details_pkey PRIMARY KEY (id);

--
-- Name: psychologist_clinical_sessions clinical_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_clinical_sessions
    ADD CONSTRAINT clinical_sessions_pkey PRIMARY KEY (id);

--
-- Name: catalog_document_templates document_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalog_document_templates
    ADD CONSTRAINT document_templates_pkey PRIMARY KEY (id);

--
-- Name: encryption_audit_log encryption_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encryption_audit_log
    ADD CONSTRAINT encryption_audit_log_pkey PRIMARY KEY (id);

--
-- Name: generated_documents generated_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generated_documents
    ADD CONSTRAINT generated_documents_pkey PRIMARY KEY (id);

--
-- Name: google_calendar_connections google_calendar_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_calendar_connections
    ADD CONSTRAINT google_calendar_connections_pkey PRIMARY KEY (id);

--
-- Name: google_sync_idempotency google_sync_idempotency_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_idempotency
    ADD CONSTRAINT google_sync_idempotency_pkey PRIMARY KEY (idempotency_key);

--
-- Name: google_sync_inbound_coalesce google_sync_inbound_coalesce_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_inbound_coalesce
    ADD CONSTRAINT google_sync_inbound_coalesce_pkey PRIMARY KEY (connection_id);

--
-- Name: google_sync_job_dedup google_sync_job_dedup_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_job_dedup
    ADD CONSTRAINT google_sync_job_dedup_pkey PRIMARY KEY (idempotency_key);

--
-- Name: google_sync_logs google_sync_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_logs
    ADD CONSTRAINT google_sync_logs_pkey PRIMARY KEY (id);

--
-- Name: google_sync_worker_metrics google_sync_worker_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_worker_metrics
    ADD CONSTRAINT google_sync_worker_metrics_pkey PRIMARY KEY (id);

--
-- Name: public_linktree_links linktree_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_linktree_links
    ADD CONSTRAINT linktree_links_pkey PRIMARY KEY (id);

--
-- Name: public_client_checkout_intents marketplace_payment_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_client_checkout_intents
    ADD CONSTRAINT marketplace_payment_intents_pkey PRIMARY KEY (id);

--
-- Name: public_client_checkout_intents marketplace_payment_intents_stripe_checkout_session_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_client_checkout_intents
    ADD CONSTRAINT marketplace_payment_intents_stripe_checkout_session_id_key UNIQUE (stripe_checkout_session_id);

--
-- Name: public_client_checkout_intents marketplace_payment_intents_stripe_payment_intent_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_client_checkout_intents
    ADD CONSTRAINT marketplace_payment_intents_stripe_payment_intent_id_key UNIQUE (stripe_payment_intent_id);

--
-- Name: busy_slots no_overlapping_busy_slots; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.busy_slots
    ADD CONSTRAINT no_overlapping_busy_slots EXCLUDE USING gist (psychologist_id WITH =, slot_range WITH &&) WHERE ((is_hard_block = true));

--
-- Name: psychologist_patient_activities patient_activity_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_activities
    ADD CONSTRAINT patient_activity_assignments_pkey PRIMARY KEY (id);

--
-- Name: patient_deletion_audit_log patient_deletion_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.patient_deletion_audit_log
    ADD CONSTRAINT patient_deletion_audit_log_pkey PRIMARY KEY (id);

--
-- Name: psychologist_patient_emergency_contacts patient_emergency_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_emergency_contacts
    ADD CONSTRAINT patient_emergency_contacts_pkey PRIMARY KEY (id);

--
-- Name: psychologist_patient_assessments patient_tests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_assessments
    ADD CONSTRAINT patient_tests_pkey PRIMARY KEY (id);

--
-- Name: user_patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (id);

--
-- Name: psychologist_assistants psychologist_assistants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_assistants
    ADD CONSTRAINT psychologist_assistants_pkey PRIMARY KEY (psychologist_id, assistant_id);

--
-- Name: psychologist_weekly_schedules psychologist_availability_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_weekly_schedules
    ADD CONSTRAINT psychologist_availability_pkey PRIMARY KEY (id);

--
-- Name: psychologist_patient_charges psychologist_client_charges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_charges
    ADD CONSTRAINT psychologist_client_charges_pkey PRIMARY KEY (id);

--
-- Name: psychologist_patient_services psychologist_client_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_services
    ADD CONSTRAINT psychologist_client_services_pkey PRIMARY KEY (id);

--
-- Name: psychologist_patients psychologist_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patients
    ADD CONSTRAINT psychologist_clients_pkey PRIMARY KEY (id);

--
-- Name: psychologist_financial_entries psychologist_financial_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_financial_entries
    ADD CONSTRAINT psychologist_financial_entries_pkey PRIMARY KEY (id);

--
-- Name: psychologist_invoices psychologist_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_invoices
    ADD CONSTRAINT psychologist_invoices_pkey PRIMARY KEY (id);

--
-- Name: public_locations psychologist_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_locations
    ADD CONSTRAINT psychologist_locations_pkey PRIMARY KEY (id);

--
-- Name: psychologist_onboarding_state psychologist_onboarding_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_onboarding_state
    ADD CONSTRAINT psychologist_onboarding_state_pkey PRIMARY KEY (psychologist_id);

--
-- Name: psychologist_patient_guardian_documents psychologist_patient_guardian_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_guardian_documents
    ADD CONSTRAINT psychologist_patient_guardian_documents_pkey PRIMARY KEY (id);

--
-- Name: psychologist_patient_guardians psychologist_patient_guardians_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_guardians
    ADD CONSTRAINT psychologist_patient_guardians_pkey PRIMARY KEY (id);

--
-- Name: psychologist_patient_medical_items psychologist_patient_medical_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_patient_medical_items
    ADD CONSTRAINT psychologist_patient_medical_items_pkey PRIMARY KEY (id);

--
-- Name: public_profiles psychologist_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_profiles
    ADD CONSTRAINT psychologist_profiles_pkey PRIMARY KEY (id);

--
-- Name: public_profiles psychologist_profiles_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.public_profiles
    ADD CONSTRAINT psychologist_profiles_slug_key UNIQUE (slug);

--
-- Name: psychologist_quick_notes psychologist_quick_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_quick_notes
    ADD CONSTRAINT psychologist_quick_notes_pkey PRIMARY KEY (id);

--
-- Name: psychologist_services psychologist_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_services
    ADD CONSTRAINT psychologist_services_pkey PRIMARY KEY (id);

--
-- Name: psychologist_session_cancellation_policy psychologist_session_cancellation_policy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_session_cancellation_policy
    ADD CONSTRAINT psychologist_session_cancellation_policy_pkey PRIMARY KEY (id);

--
-- Name: psychologist_stripe_connect psychologist_stripe_connect_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_stripe_connect
    ADD CONSTRAINT psychologist_stripe_connect_pkey PRIMARY KEY (psychologist_id);

--
-- Name: psychologist_stripe_connect psychologist_stripe_connect_stripe_account_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_stripe_connect
    ADD CONSTRAINT psychologist_stripe_connect_stripe_account_id_key UNIQUE (stripe_account_id);

--
-- Name: psychologist_subscriptions psychologist_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_subscriptions
    ADD CONSTRAINT psychologist_subscriptions_pkey PRIMARY KEY (id);

--
-- Name: psychologist_subscriptions psychologist_subscriptions_psychologist_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psychologist_subscriptions
    ADD CONSTRAINT psychologist_subscriptions_psychologist_id_key UNIQUE (psychologist_id);

--
-- Name: user_psychologists psychologists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_psychologists
    ADD CONSTRAINT psychologists_pkey PRIMARY KEY (id);
