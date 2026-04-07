-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:52Z

SET check_function_bodies = false;

--
-- Name: generated_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.generated_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_client_id uuid,
    title text,
    content text,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    patient_id uuid,
    template_id uuid,
    document_type text,
    encoded_content text DEFAULT ''::text,
    tags text[],
    is_archived boolean DEFAULT false
);

--
-- Name: google_calendar_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.google_calendar_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    access_token text,
    refresh_token text,
    token_expires_at timestamp with time zone NOT NULL,
    google_email text NOT NULL,
    google_calendar_id text DEFAULT 'primary'::text NOT NULL,
    sync_enabled boolean DEFAULT true NOT NULL,
    sync_to_google boolean DEFAULT true NOT NULL,
    sync_from_google boolean DEFAULT true NOT NULL,
    sync_sessions boolean DEFAULT true NOT NULL,
    sync_supervisions boolean DEFAULT true NOT NULL,
    sync_meetings boolean DEFAULT true NOT NULL,
    sync_tasks boolean DEFAULT false NOT NULL,
    sync_blocks boolean DEFAULT true NOT NULL,
    sync_other boolean DEFAULT false NOT NULL,
    show_patient_name boolean DEFAULT false NOT NULL,
    show_event_details boolean DEFAULT false NOT NULL,
    watch_channel_id text,
    watch_resource_id text,
    watch_expiration timestamp with time zone,
    is_connected boolean DEFAULT true NOT NULL,
    last_sync_at timestamp with time zone,
    last_sync_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    sync_token text,
    last_full_sync_at timestamp with time zone,
    last_incremental_sync_at timestamp with time zone,
    consecutive_errors integer DEFAULT 0 NOT NULL,
    access_token_encrypted text,
    refresh_token_encrypted text,
    sync_state text DEFAULT 'active'::text NOT NULL,
    last_successful_sync_at timestamp with time zone,
    last_webhook_at timestamp with time zone,
    watch_expires_at timestamp with time zone,
    last_watch_renewal_at timestamp with time zone,
    sync_token_updated_at timestamp with time zone,
    refresh_error_count integer DEFAULT 0 NOT NULL,
    last_sync_error_code text,
    watch_channel_token text,
    auto_create_meet_for_sessions boolean DEFAULT true NOT NULL,
    CONSTRAINT google_calendar_connections_sync_state_check CHECK ((sync_state = ANY (ARRAY['active'::text, 'needs_reauth'::text, 'disabled'::text, 'needs_full_resync'::text])))
);

--
-- Name: COLUMN google_calendar_connections.watch_channel_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.google_calendar_connections.watch_channel_token IS 'Opaque token used to validate Google watch notifications.';

--
-- Name: COLUMN google_calendar_connections.auto_create_meet_for_sessions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.google_calendar_connections.auto_create_meet_for_sessions IS 'Whether session events should auto-create Google Meet links by default.';

--
-- Name: google_sync_idempotency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.google_sync_idempotency (
    idempotency_key text NOT NULL,
    psychologist_id uuid NOT NULL,
    calendar_event_id uuid,
    operation text NOT NULL,
    status text NOT NULL,
    request_data jsonb,
    response_data jsonb,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    completed_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    CONSTRAINT google_sync_idempotency_operation_check CHECK ((operation = ANY (ARRAY['create'::text, 'update'::text, 'delete'::text, 'sync'::text]))),
    CONSTRAINT google_sync_idempotency_status_check CHECK ((status = ANY (ARRAY['processing'::text, 'completed'::text, 'failed'::text])))
);

--
-- Name: google_sync_inbound_coalesce; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.google_sync_inbound_coalesce (
    connection_id uuid NOT NULL,
    msg_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_enqueued_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: google_sync_job_dedup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.google_sync_job_dedup (
    idempotency_key text NOT NULL,
    processed_at timestamp with time zone DEFAULT now() NOT NULL,
    outcome jsonb
);

--
-- Name: google_sync_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.google_sync_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    calendar_event_id uuid,
    series_id uuid,
    google_event_id text,
    sync_direction public.sync_direction NOT NULL,
    operation public.sync_operation NOT NULL,
    status public.sync_result_status NOT NULL,
    request_payload jsonb,
    response_payload jsonb,
    error_message text,
    error_code text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: google_sync_worker_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.google_sync_worker_metrics (
    id bigint NOT NULL,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    worker_id text,
    queue_name text NOT NULL,
    batch_size integer DEFAULT 0 NOT NULL,
    successful integer DEFAULT 0 NOT NULL,
    failed integer DEFAULT 0 NOT NULL,
    skipped integer DEFAULT 0 NOT NULL,
    requeued integer DEFAULT 0 NOT NULL,
    duration_ms integer DEFAULT 0 NOT NULL,
    backlog_after bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);

--
-- Name: google_sync_worker_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.google_sync_worker_metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

--
-- Name: google_sync_worker_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.google_sync_worker_metrics_id_seq OWNED BY public.google_sync_worker_metrics.id;

--
-- Name: patient_deletion_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.patient_deletion_audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cleanup_timestamp timestamp with time zone NOT NULL,
    deleted_count integer DEFAULT 0 NOT NULL,
    triggered_by text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: TABLE patient_deletion_audit_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.patient_deletion_audit_log IS 'Audit log for patient deletion cleanup operations';

--
-- Name: psychologist_assistants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_assistants (
    psychologist_id uuid NOT NULL,
    assistant_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    revoked_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb
);

--
-- Name: TABLE psychologist_assistants; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.psychologist_assistants IS 'Active and historical relationships between psychologists and their assistants. This table is the source of truth for data access permissions.';

--
-- Name: COLUMN psychologist_assistants.psychologist_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_assistants.psychologist_id IS 'The owner of the clinical data (the psychologist).';

--
-- Name: COLUMN psychologist_assistants.assistant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_assistants.assistant_id IS 'The user granted access to act as an assistant.';

--
-- Name: COLUMN psychologist_assistants.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_assistants.created_at IS 'Timestamp when the assistant relationship was established (usually via invite acceptance).';

--
-- Name: COLUMN psychologist_assistants.revoked_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_assistants.revoked_at IS 'Timestamp when the assistant''s access was terminated by the psychologist. If NULL, access is active.';

--
-- Name: COLUMN psychologist_assistants.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_assistants.metadata IS 'Additional relationship context (e.g., origin invite ID, notes, etc.).';

--
-- Name: psychologist_weekly_schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_weekly_schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    day_of_week integer NOT NULL,
    delivery_mode public.delivery_mode NOT NULL,
    effective_start date,
    effective_end date,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    available_for_first_appointment boolean DEFAULT true,
    location_id uuid,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    daily_appointment_limit integer,
    CONSTRAINT psychologist_weekly_schedules_slot_check CHECK (((EXTRACT(minute FROM start_time) = ANY (ARRAY[(0)::numeric, (30)::numeric])) AND (EXTRACT(second FROM start_time) = (0)::numeric)))
);

--
-- Name: TABLE psychologist_weekly_schedules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.psychologist_weekly_schedules IS 'Defines recurring weekly working hours for a psychologist.';

--
-- Name: COLUMN psychologist_weekly_schedules.daily_appointment_limit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_weekly_schedules.daily_appointment_limit IS 'Maximum number of appointments allowed for this time interval per day. NULL means unlimited.';

--
-- Name: psychologist_derived_modality; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.psychologist_derived_modality WITH (security_invoker='true') AS
 SELECT psychologist_id,
        CASE
            WHEN bool_or((delivery_mode = 'hybrid'::public.delivery_mode)) THEN 'hybrid'::public.practice_modality
            WHEN (bool_or((delivery_mode = 'in_person'::public.delivery_mode)) AND bool_or((delivery_mode = 'telehealth'::public.delivery_mode))) THEN 'hybrid'::public.practice_modality
            WHEN bool_or((delivery_mode = 'in_person'::public.delivery_mode)) THEN 'in_person'::public.practice_modality
            WHEN bool_or((delivery_mode = 'telehealth'::public.delivery_mode)) THEN 'online'::public.practice_modality
            ELSE 'online'::public.practice_modality
        END AS practice_modality
   FROM public.psychologist_weekly_schedules pa
  WHERE ((is_active = true) AND ((effective_start IS NULL) OR (effective_start <= CURRENT_DATE)) AND ((effective_end IS NULL) OR (effective_end >= CURRENT_DATE)))
  GROUP BY psychologist_id;

--
-- Name: psychologist_financial_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_financial_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    type text NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    date_time timestamp with time zone DEFAULT now() NOT NULL,
    status public.financial_entry_status,
    payment_method public.payment_method_type,
    description text,
    charge_id uuid,
    session_id uuid,
    parent_recurrence_id uuid,
    transaction_category_id uuid,
    is_automatically_generated boolean DEFAULT false,
    weekly_period_start timestamp with time zone,
    weekly_period_end timestamp with time zone,
    charges_count integer,
    consolidation_type text,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    attachment_url text,
    notes text,
    billing_id uuid
);

--
-- Name: TABLE psychologist_financial_entries; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.psychologist_financial_entries IS 'Financial transactions (income and expenses) for the psychologist.

Daily Consolidation:
- Paid charges are consolidated into daily entries based on session date
- The date_time field stores the session date at 00:00 UTC
- Description format: "Serviços Prestados DD MMM"
- One entry per day per psychologist, updated as charges are paid/unpaid';
