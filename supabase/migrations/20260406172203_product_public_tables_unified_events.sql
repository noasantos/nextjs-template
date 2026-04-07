-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:03Z

SET check_function_bodies = false;

--
-- Name: unified_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unified_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_family text NOT NULL,
    event_name text NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL,
    trace_id uuid DEFAULT gen_random_uuid() NOT NULL,
    correlation_id uuid,
    service text NOT NULL,
    component text NOT NULL,
    environment text NOT NULL,
    actor_type text NOT NULL,
    actor_id_hash text,
    role text,
    operation text NOT NULL,
    operation_type text NOT NULL,
    outcome text NOT NULL,
    error_category text,
    error_code text,
    error_message text,
    duration_ms integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    sample_rate double precision DEFAULT 1.0 NOT NULL,
    force_keep boolean DEFAULT true NOT NULL,
    retention_days integer DEFAULT 90,
    request_path text,
    http_status integer,
    ip_address text,
    user_agent text,
    CONSTRAINT unified_events_actor_type_check CHECK ((actor_type = ANY (ARRAY['anonymous'::text, 'authenticated'::text, 'system'::text, 'service-role'::text]))),
    CONSTRAINT unified_events_environment_check CHECK ((environment = ANY (ARRAY['local'::text, 'dev'::text, 'stg'::text, 'prod'::text]))),
    CONSTRAINT unified_events_event_family_check CHECK ((event_family = ANY (ARRAY['security_audit'::text, 'operational'::text, 'stripe_webhook'::text]))),
    CONSTRAINT unified_events_outcome_check CHECK ((outcome = ANY (ARRAY['success'::text, 'failure'::text, 'error'::text, 'timeout'::text, 'circuit_open'::text, 'rate_limited'::text, 'received'::text, 'processed'::text])))
);

--
-- Name: TABLE unified_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.unified_events IS 'Central repository for all operational events. Replaces service_role_audit_log. See ADR 009 for details.';

--
-- Name: user_admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_admins (
    id uuid NOT NULL,
    first_name text,
    last_name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    permissions text[] DEFAULT '{}'::text[],
    metadata jsonb DEFAULT '{}'::jsonb
);

--
-- Name: TABLE user_admins; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_admins IS 'Core identity table for internal platform administrators. Extends auth.users.';

--
-- Name: COLUMN user_admins.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_admins.id IS 'Unique identifier for the admin, linking to auth.users.';

--
-- Name: COLUMN user_admins.first_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_admins.first_name IS 'Admin''s first name for internal identification.';

--
-- Name: COLUMN user_admins.last_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_admins.last_name IS 'Admin''s last name for internal identification.';

--
-- Name: COLUMN user_admins.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_admins.is_active IS 'Flag to enable or disable admin access without deleting the record.';

--
-- Name: COLUMN user_admins.permissions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_admins.permissions IS 'Array of specific permission strings (e.g., "manage_activities", "edit_templates") for granular access control.';

--
-- Name: COLUMN user_admins.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_admins.metadata IS 'Flexible storage for admin-specific settings or future metadata.';

--
-- Name: user_assistants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_assistants (
    id uuid NOT NULL,
    first_name text,
    last_name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: TABLE user_assistants; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_assistants IS 'Core identity table for clinic assistants and secretaries. Extends auth.users.';

--
-- Name: user_patients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_patients (
    id uuid NOT NULL,
    first_name text,
    last_name text,
    display_name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    full_name text GENERATED ALWAYS AS (TRIM(BOTH FROM ((first_name || ' '::text) || last_name))) STORED,
    preferred_name text
);

--
-- Name: TABLE user_patients; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_patients IS 'Core identity table for patients (global profile). Extends auth.users.';

--
-- Name: v_operational_events; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_operational_events WITH (security_invoker='true') AS
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
   FROM public.unified_events
  WHERE (event_family = 'operational'::text);

--
-- Name: v_service_role_audit; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_service_role_audit WITH (security_invoker='true') AS
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
   FROM public.unified_events
  WHERE (event_family = 'security_audit'::text);

--
-- Name: v_stripe_webhook_events; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_stripe_webhook_events WITH (security_invoker='true') AS
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
   FROM public.unified_events
  WHERE (event_family = 'stripe_webhook'::text);

--
-- Name: view_sync_backlog; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_sync_backlog WITH (security_invoker='true') AS
 SELECT count(*) AS total_backlog,
    count(*) FILTER (WHERE (updated_at < (now() - '01:00:00'::interval))) AS stuck_events_1h
   FROM public.calendar_events
  WHERE (google_sync_status = 'pending'::public.google_sync_status);

--
-- Name: view_sync_health_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_sync_health_stats WITH (security_invoker='true') AS
 SELECT ce.psychologist_id,
    p.full_name AS psychologist_name,
    count(*) AS total_events,
    count(*) FILTER (WHERE (ce.google_sync_status = 'pending'::public.google_sync_status)) AS pending_count,
    count(*) FILTER (WHERE (ce.google_sync_status = 'synced'::public.google_sync_status)) AS synced_count,
    count(*) FILTER (WHERE (ce.google_sync_status = 'error'::public.google_sync_status)) AS error_count,
    max(ce.last_synced_at) AS last_sync_activity,
    gcc.sync_sessions,
    gcc.updated_at AS connection_updated_at
   FROM ((public.calendar_events ce
     JOIN public.user_psychologists p ON ((ce.psychologist_id = p.id)))
     LEFT JOIN public.google_calendar_connections gcc ON ((ce.psychologist_id = gcc.psychologist_id)))
  GROUP BY ce.psychologist_id, p.full_name, gcc.sync_sessions, gcc.updated_at;

--
-- Name: webhook_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source text NOT NULL,
    event_id text,
    channel_id text,
    resource_id text,
    event_type text,
    payload_hash text,
    processed boolean DEFAULT false,
    processing_error text,
    ip_address text,
    received_at timestamp with time zone DEFAULT now(),
    processed_at timestamp with time zone
);

--
-- Name: webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_events (
    event_id text NOT NULL,
    payload jsonb,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: google_sync_worker_metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.google_sync_worker_metrics ALTER COLUMN id SET DEFAULT nextval('public.google_sync_worker_metrics_id_seq'::regclass);

--
-- Name: account_deletion_requests account_deletion_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_deletion_requests
    ADD CONSTRAINT account_deletion_requests_pkey PRIMARY KEY (id);

--
-- Name: user_admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);

--
-- Name: assistant_invites assistant_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assistant_invites
    ADD CONSTRAINT assistant_invites_pkey PRIMARY KEY (id);

--
-- Name: user_assistants assistants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_assistants
    ADD CONSTRAINT assistants_pkey PRIMARY KEY (id);

--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);

--
-- Name: availability_exceptions availability_exceptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_exceptions
    ADD CONSTRAINT availability_exceptions_pkey PRIMARY KEY (id);

--
-- Name: busy_slots busy_slots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.busy_slots
    ADD CONSTRAINT busy_slots_pkey PRIMARY KEY (id);

--
-- Name: calendar_change_log calendar_change_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_change_log
    ADD CONSTRAINT calendar_change_log_pkey PRIMARY KEY (id);
