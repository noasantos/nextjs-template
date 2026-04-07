-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:46Z

SET check_function_bodies = false;

--
-- Name: calendar_change_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_change_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    google_event_id text NOT NULL,
    modification_hash text NOT NULL,
    sync_direction text NOT NULL,
    processed_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT calendar_change_log_sync_direction_check CHECK ((sync_direction = ANY (ARRAY['google_to_fluri'::text, 'fluri_to_google'::text])))
);

--
-- Name: TABLE calendar_change_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.calendar_change_log IS 'Audit log for calendar event changes';

--
-- Name: calendar_event_series; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_event_series (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    event_type public.calendar_event_type NOT NULL,
    title text NOT NULL,
    description text,
    location text,
    color text,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    duration_minutes integer DEFAULT 50 NOT NULL,
    timezone text DEFAULT 'America/Sao_Paulo'::text NOT NULL,
    all_day boolean DEFAULT false NOT NULL,
    rrule text NOT NULL,
    effective_start date NOT NULL,
    effective_end date,
    google_event_id text,
    google_sync_status public.google_sync_status DEFAULT 'not_synced'::public.google_sync_status NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT valid_duration CHECK ((duration_minutes > 0)),
    CONSTRAINT valid_time_range CHECK ((start_time < end_time))
);

--
-- Name: calendar_event_series_exceptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_event_series_exceptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    series_id uuid NOT NULL,
    original_date date NOT NULL,
    exception_type public.series_exception_type NOT NULL,
    new_start_datetime timestamp with time zone,
    new_end_datetime timestamp with time zone,
    modified_fields jsonb,
    reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: calendar_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    series_id uuid,
    event_type public.calendar_event_type NOT NULL,
    title text NOT NULL,
    description text,
    location text,
    color text,
    start_datetime timestamp with time zone NOT NULL,
    end_datetime timestamp with time zone NOT NULL,
    duration_minutes integer NOT NULL,
    timezone text DEFAULT 'America/Sao_Paulo'::text NOT NULL,
    all_day boolean DEFAULT false NOT NULL,
    original_start_datetime timestamp with time zone,
    original_end_datetime timestamp with time zone,
    status public.calendar_event_status DEFAULT 'scheduled'::public.calendar_event_status NOT NULL,
    source public.calendar_event_source DEFAULT 'fluri'::public.calendar_event_source NOT NULL,
    google_event_id text,
    google_sync_status public.google_sync_status DEFAULT 'not_synced'::public.google_sync_status NOT NULL,
    google_sync_error text,
    last_synced_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    private_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    google_recurring_event_id text,
    google_original_start_time timestamp with time zone,
    sync_origin text DEFAULT 'user'::text NOT NULL,
    remote_updated_at timestamp with time zone,
    remote_etag text,
    CONSTRAINT calendar_events_sync_origin_check CHECK ((sync_origin = ANY (ARRAY['user'::text, 'google'::text, 'system'::text]))),
    CONSTRAINT valid_datetime_range CHECK ((start_datetime < end_datetime))
);

--
-- Name: psychologist_clinical_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_clinical_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_patient_id uuid,
    psychologist_service_id uuid,
    location_id uuid,
    start_time timestamp with time zone DEFAULT now() NOT NULL,
    duration_minutes integer,
    status text DEFAULT 'scheduled'::text,
    custom_price_cents integer,
    snapshot_price integer,
    snapshot_price_cents integer,
    snapshot_service_name text,
    notes text,
    default_charge_id uuid,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    calendar_event_id uuid,
    session_number integer,
    attendance_confirmed boolean DEFAULT false,
    confirmation_sent_at timestamp with time zone,
    reminder_sent_at timestamp with time zone,
    billing_status text,
    billing_next_attempt_at timestamp with time zone,
    billing_attempt_count integer DEFAULT 0,
    billing_last_error text,
    automation_metadata jsonb DEFAULT '{}'::jsonb,
    note_id uuid,
    status_reason text
);

--
-- Name: COLUMN psychologist_clinical_sessions.psychologist_patient_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_clinical_sessions.psychologist_patient_id IS 'Reference to the psychologist_patients table (the patient record for this psychologist)';

--
-- Name: COLUMN psychologist_clinical_sessions.attendance_confirmed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_clinical_sessions.attendance_confirmed IS 'Whether patient confirmed attendance';

--
-- Name: COLUMN psychologist_clinical_sessions.confirmation_sent_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_clinical_sessions.confirmation_sent_at IS 'When confirmation was last sent/received';

--
-- Name: COLUMN psychologist_clinical_sessions.reminder_sent_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_clinical_sessions.reminder_sent_at IS 'When 24h reminder was sent';

--
-- Name: COLUMN psychologist_clinical_sessions.billing_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_clinical_sessions.billing_status IS 'Current billing status: pending, processing, completed, failed';

--
-- Name: COLUMN psychologist_clinical_sessions.billing_next_attempt_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_clinical_sessions.billing_next_attempt_at IS 'When to next attempt billing (for failed payments)';

--
-- Name: COLUMN psychologist_clinical_sessions.billing_attempt_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_clinical_sessions.billing_attempt_count IS 'Number of billing attempts made';

--
-- Name: COLUMN psychologist_clinical_sessions.automation_metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_clinical_sessions.automation_metadata IS 'JSONB tracking reminders, confirmations, and automation state';

--
-- Name: psychologist_patients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    patient_id uuid,
    manual_full_name text,
    synced_full_name text,
    manual_display_name text,
    synced_display_name text,
    manual_email text,
    manual_phone text,
    manual_date_of_birth date,
    synced_date_of_birth date,
    preferred_contact_method public.contact_method_type,
    status text DEFAULT 'active'::text,
    risk_level text,
    initial_complaint text,
    clinical_hypothesis text,
    therapeutic_goals jsonb,
    default_session_price integer,
    relationship_start_date date,
    informed_consent_signed boolean DEFAULT false,
    informed_consent_date date,
    data_sharing_consent boolean DEFAULT false,
    data_sharing_consent_date date,
    invite_status public.invite_status_type,
    invite_sent_via public.contact_method_type,
    invited_at timestamp with time zone,
    last_session_date date,
    total_sessions_count integer DEFAULT 0,
    deleted_at timestamp with time zone,
    recovery_deadline timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    manual_patient_origin text,
    manual_first_name text,
    manual_last_name text,
    manual_preferred_name text,
    synced_phone text,
    synced_email text,
    manual_cpf text,
    synced_cpf text,
    manual_rg text,
    synced_rg text,
    manual_gender text,
    synced_gender text,
    manual_pronouns text,
    synced_pronouns text,
    manual_place_of_birth text,
    synced_place_of_birth text,
    manual_profession text,
    synced_profession text,
    is_minor boolean DEFAULT false,
    treatment_plan text,
    first_session_date date,
    manual_address jsonb,
    relationship_end_date date,
    discharge_reason text,
    requires_legal_guardian boolean DEFAULT false,
    clinical_notes text,
    disorders jsonb DEFAULT '[]'::jsonb,
    current_medications jsonb DEFAULT '[]'::jsonb,
    known_allergies jsonb DEFAULT '[]'::jsonb,
    suicide_risk_assessment text,
    price_set_at timestamp with time zone,
    price_set_by uuid,
    informed_consent_document_url text,
    invite_expires_at timestamp with time zone,
    invite_reminder_sent_at timestamp with time zone,
    invite_reminder_count integer DEFAULT 0,
    retention_until timestamp with time zone,
    archived_at timestamp with time zone,
    archived_by uuid,
    manual_emergency_contacts jsonb,
    attached_documents jsonb DEFAULT '[]'::jsonb,
    deleted_by uuid,
    invite_token text,
    synced_address jsonb
);

--
-- Name: TABLE psychologist_patients; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.psychologist_patients IS 'Psychologist-specific patient records. Links a global user_patients record to a specific psychologist with custom fields like manual vs synced data, pricing, and relationship metadata.';

--
-- Name: COLUMN psychologist_patients.manual_display_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.manual_display_name IS 'Auto-generated display name following the rule: 
- If name is compound (≥2 words): use compound name (e.g., "Ana Luiza")
- If simple name + surname: use name + last surname word (e.g., "Ana Silva")
- If only name: use name only (e.g., "Ana")
Priority: manual_preferred_name → manual_first_name';

--
-- Name: COLUMN psychologist_patients.recovery_deadline; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.recovery_deadline IS 'Deadline for soft-delete recovery';

--
-- Name: COLUMN psychologist_patients.synced_phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.synced_phone IS 'Phone synced from linked patient identity/provider when available.';

--
-- Name: COLUMN psychologist_patients.synced_email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.synced_email IS 'Email synced from linked patient identity/provider when available.';

--
-- Name: COLUMN psychologist_patients.manual_cpf; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.manual_cpf IS 'CPF entered manually by psychologist';

--
-- Name: COLUMN psychologist_patients.synced_cpf; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.synced_cpf IS 'CPF synced from external source';

--
-- Name: COLUMN psychologist_patients.manual_rg; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.manual_rg IS 'RG entered manually';

--
-- Name: COLUMN psychologist_patients.synced_rg; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.synced_rg IS 'RG synced from external source';

--
-- Name: COLUMN psychologist_patients.manual_gender; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.manual_gender IS 'Gender entered manually';

--
-- Name: COLUMN psychologist_patients.synced_gender; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.synced_gender IS 'Gender synced from external source';
