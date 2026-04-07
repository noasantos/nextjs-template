-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:49Z

SET check_function_bodies = false;

--
-- Name: COLUMN psychologist_patients.manual_pronouns; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.manual_pronouns IS 'Pronouns entered manually';

--
-- Name: COLUMN psychologist_patients.synced_pronouns; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.synced_pronouns IS 'Pronouns synced from external source';

--
-- Name: COLUMN psychologist_patients.manual_place_of_birth; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.manual_place_of_birth IS 'Place of birth entered manually';

--
-- Name: COLUMN psychologist_patients.synced_place_of_birth; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.synced_place_of_birth IS 'Place of birth synced from external source';

--
-- Name: COLUMN psychologist_patients.manual_profession; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.manual_profession IS 'Profession entered manually';

--
-- Name: COLUMN psychologist_patients.synced_profession; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.synced_profession IS 'Profession synced from external source';

--
-- Name: COLUMN psychologist_patients.is_minor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.is_minor IS 'Whether the patient is under 18; can be derived from date_of_birth if not set';

--
-- Name: COLUMN psychologist_patients.treatment_plan; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.treatment_plan IS 'Treatment plan text for document templates';

--
-- Name: COLUMN psychologist_patients.first_session_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.first_session_date IS 'Date of first session with this psychologist';

--
-- Name: COLUMN psychologist_patients.manual_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.manual_address IS 'Manual address (JSON) for document templates';

--
-- Name: COLUMN psychologist_patients.relationship_end_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.relationship_end_date IS 'End date of therapeutic relationship';

--
-- Name: COLUMN psychologist_patients.discharge_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.discharge_reason IS 'Reason for discharge if applicable';

--
-- Name: COLUMN psychologist_patients.requires_legal_guardian; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.requires_legal_guardian IS 'Whether patient requires legal guardian consent';

--
-- Name: COLUMN psychologist_patients.clinical_notes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.clinical_notes IS 'Private clinical notes';

--
-- Name: COLUMN psychologist_patients.attached_documents; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patients.attached_documents IS 'Attached documents metadata (JSON array)';

--
-- Name: psychologist_services; Type: TABLE; Schema: public; Owner: -
--


CREATE TABLE public.psychologist_services (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    service_id uuid,
    name text,
    description text,
    price integer,
    duration_minutes integer,
    is_active boolean DEFAULT true NOT NULL,
    is_public boolean DEFAULT false,
    sort_order integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    catalog_id uuid
);

--
-- Name: calendar_events_full; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.calendar_events_full WITH (security_invoker='true') AS
 SELECT e.id,
    e.psychologist_id,
    e.series_id,
    e.event_type,
    e.title,
    e.description,
    e.location,
    e.color,
    e.start_datetime,
    e.end_datetime,
    e.duration_minutes,
    e.timezone,
    e.all_day,
    e.original_start_datetime,
    e.original_end_datetime,
    e.status,
    e.source,
    e.google_event_id,
    e.google_sync_status,
    e.google_sync_error,
    e.last_synced_at,
    e.metadata,
    e.private_notes,
    e.created_at,
    e.updated_at,
    cs.psychologist_patient_id,
    cs.psychologist_service_id,
    cs.session_number,
    cs.id AS clinical_session_id,
    cs.attendance_confirmed,
    cs.billing_status,
    COALESCE(p.manual_full_name, p.synced_full_name) AS patient_name,
    COALESCE(p.manual_display_name, p.synced_display_name) AS patient_display_name,
    ps.name AS service_name,
    ps.price AS service_price,
    ps.duration_minutes AS service_duration
   FROM (((public.calendar_events e
     LEFT JOIN public.psychologist_clinical_sessions cs ON ((cs.calendar_event_id = e.id)))
     LEFT JOIN public.psychologist_patients p ON ((p.id = cs.psychologist_patient_id)))
     LEFT JOIN public.psychologist_services ps ON ((ps.id = cs.psychologist_service_id)));

--
-- Name: VIEW calendar_events_full; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.calendar_events_full IS 'Comprehensive view of calendar events with session, patient, and service details. Updated to use psychologist_patient_id column naming.';

--
-- Name: calendar_holidays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_holidays (
    id bigint NOT NULL,
    year integer NOT NULL,
    state text,
    city text,
    date date NOT NULL,
    name text NOT NULL,
    type text,
    description text,
    source text DEFAULT 'feriados.dev'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

--
-- Name: TABLE calendar_holidays; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.calendar_holidays IS 'Stores Brazilian holidays (national, state, municipal) cached from feriados.dev.';

--
-- Name: calendar_holidays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.calendar_holidays ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.calendar_holidays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

--
-- Name: catalog_clinical_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catalog_clinical_activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text,
    title text,
    description text,
    active boolean DEFAULT true,
    pdf_path text,
    media_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    image_path text,
    activity_kind text,
    duration_min integer,
    goals text[],
    populations text[],
    delivery_modes text[],
    materials_json jsonb,
    clinician_notes_template text,
    risk_level text,
    tags text[]
);

--
-- Name: COLUMN catalog_clinical_activities.activity_kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.activity_kind IS 'Activity classification/kind from production catalog.';

--
-- Name: COLUMN catalog_clinical_activities.duration_min; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.duration_min IS 'Suggested activity duration in minutes.';

--
-- Name: COLUMN catalog_clinical_activities.goals; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.goals IS 'Structured goals list for activity prescription.';

--
-- Name: COLUMN catalog_clinical_activities.populations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.populations IS 'Target populations for activity use.';

--
-- Name: COLUMN catalog_clinical_activities.delivery_modes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.delivery_modes IS 'Allowed delivery modes (in-person/online/etc).';

--
-- Name: COLUMN catalog_clinical_activities.materials_json; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.materials_json IS 'Supplemental structured materials metadata.';

--
-- Name: COLUMN catalog_clinical_activities.clinician_notes_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.clinician_notes_template IS 'Template text for clinician guidance notes.';

--
-- Name: COLUMN catalog_clinical_activities.risk_level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.risk_level IS 'Risk level metadata for activity usage context.';

--
-- Name: COLUMN catalog_clinical_activities.tags; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.catalog_clinical_activities.tags IS 'Tag labels used for filtering/catalog navigation.';

--
-- Name: catalog_document_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catalog_document_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    description text,
    template_category text DEFAULT 'other'::text NOT NULL,
    template_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    usage_count integer DEFAULT 0
);

--
-- Name: clinical_session_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clinical_session_details (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    calendar_event_id uuid NOT NULL,
    psychologist_client_id uuid,
    psychologist_service_id uuid,
    patient_id uuid,
    session_type_id uuid,
    session_number integer,
    clinical_session_id uuid,
    attendance_confirmed boolean DEFAULT false,
    confirmation_sent_at timestamp with time zone,
    reminder_sent_at timestamp with time zone,
    billing_status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    billing_next_attempt_at timestamp with time zone,
    billing_attempt_count integer DEFAULT 0 NOT NULL,
    billing_last_attempt_at timestamp with time zone,
    billing_last_error text
);

--
-- Name: TABLE clinical_session_details; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.clinical_session_details IS 'Additional clinical details for therapy sessions';

--
-- Name: encryption_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.encryption_audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    operation text NOT NULL,
    success boolean NOT NULL,
    error_message text,
    caller_role text DEFAULT CURRENT_USER,
    caller_user_id uuid,
    context text,
    attempted_at timestamp with time zone DEFAULT now()
);

--
-- Name: TABLE encryption_audit_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.encryption_audit_log IS 'Audit log for encryption operations';
