-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:54Z

SET check_function_bodies = false;

--
-- Name: psychologist_invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_invoices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    stripe_invoice_id text,
    stripe_subscription_id text,
    status text,
    amount_paid integer,
    currency text,
    period_start date,
    period_end date,
    hosted_invoice_url text,
    invoice_pdf text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: psychologist_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_client_id uuid,
    patient_id uuid,
    session_id uuid,
    note_type public.clinical_note_type DEFAULT 'clinical_note'::public.clinical_note_type,
    title text,
    encoded_content text DEFAULT ''::text NOT NULL,
    tags text[],
    is_archived boolean DEFAULT false,
    content text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    parent_note_id uuid,
    CONSTRAINT clinical_note_no_parent_check CHECK ((((note_type = 'clinical_note'::public.clinical_note_type) AND (parent_note_id IS NULL)) OR (note_type = 'progress_note'::public.clinical_note_type)))
);

--
-- Name: COLUMN psychologist_notes.note_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_notes.note_type IS 'Note type: clinical_note (no parent_note_id) or progress_note (may have parent_note_id)';

--
-- Name: COLUMN psychologist_notes.parent_note_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_notes.parent_note_id IS 'Self-reference for progress_note chaining. Always NULL for clinical_note.';

--
-- Name: psychologist_onboarding_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_onboarding_state (
    psychologist_id uuid NOT NULL,
    current_step integer DEFAULT 1,
    draft_data jsonb DEFAULT '{}'::jsonb,
    onboarding_completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    payment_step_completed boolean DEFAULT false,
    identity_step_completed boolean DEFAULT false,
    professional_step_completed boolean DEFAULT false,
    configuration_step_completed boolean DEFAULT false,
    profile_step_completed boolean DEFAULT false,
    total_steps integer DEFAULT 5,
    last_resumed_at timestamp with time zone,
    abandoned_at timestamp with time zone,
    completion_percentage integer DEFAULT 0,
    operational_step_completed boolean DEFAULT false
);

--
-- Name: TABLE psychologist_onboarding_state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.psychologist_onboarding_state IS 'Estado de progresso do onboarding do psicólogo. Fonte única de verdade para jornada de onboarding.
- payment_step: essencial/bloqueante (usuário pagou = pode usar o sistema)
- identity/professional/readiness/profile: passos do wizard de perfil
- onboarding_completed_at: preenchido quando TODOS os passos são concluídos';

--
-- Name: COLUMN psychologist_onboarding_state.onboarding_completed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_onboarding_state.onboarding_completed_at IS 'Data de conclusão completa do onboarding (todos os passos). NULL = onboarding incompleto.';

--
-- Name: COLUMN psychologist_onboarding_state.payment_step_completed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_onboarding_state.payment_step_completed IS 'ESSENCIAL: Usuário pagou o plano. Quando TRUE, permite acesso ao sistema mesmo que outros passos estejam pendentes.';

--
-- Name: COLUMN psychologist_onboarding_state.identity_step_completed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_onboarding_state.identity_step_completed IS 'Passo 1: Dados de identidade (nome, CRP, etc)';

--
-- Name: COLUMN psychologist_onboarding_state.professional_step_completed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_onboarding_state.professional_step_completed IS 'Passo 2: Dados profissionais (especialidades, abordagens)';

--
-- Name: COLUMN psychologist_onboarding_state.configuration_step_completed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_onboarding_state.configuration_step_completed IS 'Passo 3: Configurações de prontidão (disponibilidade)';

--
-- Name: COLUMN psychologist_onboarding_state.profile_step_completed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_onboarding_state.profile_step_completed IS 'Passo 4: Perfil público (bio, foto, etc)';

--
-- Name: psychologist_onboarding_status; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.psychologist_onboarding_status WITH (security_invoker='true') AS
 SELECT psychologist_id,
    current_step,
    completion_percentage,
    total_steps,
    identity_step_completed,
    professional_step_completed,
    payment_step_completed,
    configuration_step_completed,
    profile_step_completed,
    (identity_step_completed AND professional_step_completed AND payment_step_completed) AS essential_complete,
    (identity_step_completed AND professional_step_completed AND payment_step_completed AND configuration_step_completed AND profile_step_completed) AS fully_complete,
        CASE
            WHEN (onboarding_completed_at IS NOT NULL) THEN 'completed'::text
            WHEN (identity_step_completed AND professional_step_completed AND payment_step_completed) THEN 'in_progress'::text
            ELSE 'pending'::text
        END AS status,
    onboarding_completed_at,
    last_resumed_at,
    abandoned_at
   FROM public.psychologist_onboarding_state;

--
-- Name: user_psychologists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_psychologists (
    id uuid NOT NULL,
    full_name text,
    display_name text,
    phone text,
    business_type public.business_type,
    timezone text,
    crp text,
    crp_state text,
    onboarding_completed boolean DEFAULT false,
    subscription_status text,
    stripe_customer_id text,
    stripe_subscription_id text,
    first_name text,
    last_name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    cpf text
);

--
-- Name: TABLE user_psychologists; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_psychologists IS 'Core identity table for psychologists (the primary platform users). Extends auth.users.';

--
-- Name: COLUMN user_psychologists.subscription_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_psychologists.subscription_status IS 'Current status of the psychologist''s own subscription.';

--
-- Name: COLUMN user_psychologists.stripe_customer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_psychologists.stripe_customer_id IS 'The primary Stripe identity for the psychologist (Clover v2 Customer ID). Used for both paying their own subscription and receiving payments via Connect.';

--
-- Name: COLUMN user_psychologists.stripe_subscription_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_psychologists.stripe_subscription_id IS 'Redundant reference to the current active subscription ID for performance in simple queries.';

--
-- Name: psychologist_onboarding_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.psychologist_onboarding_summary WITH (security_invoker='true') AS
 SELECT pos.psychologist_id,
    pos.payment_step_completed,
    pos.identity_step_completed,
    pos.professional_step_completed,
    pos.configuration_step_completed,
    pos.profile_step_completed,
    pos.current_step,
    pos.total_steps,
    pos.completion_percentage,
    pos.onboarding_completed_at,
    pos.last_resumed_at,
    pos.abandoned_at,
    (COALESCE((up.subscription_status = ANY (ARRAY['active'::text, 'trialing'::text])), false) OR pos.payment_step_completed) AS essential_complete,
    ((pos.onboarding_completed_at IS NOT NULL) OR (pos.payment_step_completed AND pos.identity_step_completed AND pos.professional_step_completed AND pos.configuration_step_completed AND pos.profile_step_completed)) AS fully_complete,
        CASE
            WHEN (pos.onboarding_completed_at IS NOT NULL) THEN NULL::text
            WHEN (NOT pos.payment_step_completed) THEN 'subscription'::text
            WHEN (NOT pos.identity_step_completed) THEN 'identity'::text
            WHEN (NOT pos.professional_step_completed) THEN 'professional'::text
            WHEN (NOT pos.configuration_step_completed) THEN 'configuration'::text
            WHEN (NOT pos.profile_step_completed) THEN 'profile'::text
            ELSE NULL::text
        END AS next_pending_step,
    up.subscription_status
   FROM (public.psychologist_onboarding_state pos
     LEFT JOIN public.user_psychologists up ON ((up.id = pos.psychologist_id)));

--
-- Name: psychologist_patient_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patient_activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_client_id uuid,
    title text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    response_data jsonb,
    submitted_at timestamp with time zone,
    patient_id uuid,
    activity_id uuid,
    assigned_at timestamp with time zone DEFAULT now(),
    due_date date,
    instructions text,
    status text DEFAULT 'pending'::text,
    is_archived boolean DEFAULT false,
    patient_feedback text,
    therapist_comment text,
    created_by uuid,
    updated_by uuid,
    completed_at timestamp with time zone
);

--
-- Name: psychologist_patient_assessments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patient_assessments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_client_id uuid,
    name text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    patient_id uuid,
    test_id uuid,
    test_name text,
    test_type text,
    test_date date,
    applied_at timestamp with time zone,
    results text,
    interpretation text,
    psychologist_notes text,
    notes text,
    file_url text,
    clinical_note_id uuid,
    status text DEFAULT 'pending'::text,
    tags text[],
    is_archived boolean DEFAULT false,
    created_by uuid,
    updated_by uuid
);

--
-- Name: psychologist_patient_charges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patient_charges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_patient_id uuid,
    session_id uuid,
    price_cents integer DEFAULT 0,
    due_date date,
    paid_at timestamp with time zone,
    payment_status text DEFAULT 'pending'::text,
    payment_method public.payment_method_type,
    description text,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    attachment_url text,
    payment_notes text,
    invoice_number text,
    invoice_url text,
    document_status text,
    last_sent_at timestamp with time zone,
    sent_count integer DEFAULT 0
);

--
-- Name: COLUMN psychologist_patient_charges.psychologist_patient_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patient_charges.psychologist_patient_id IS 'Reference to the psychologist_patients table';

--
-- Name: psychologist_patient_emergency_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patient_emergency_contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_patient_id uuid NOT NULL,
    contact_name text NOT NULL,
    relationship text,
    phone text,
    email text,
    is_primary boolean DEFAULT false,
    notes text,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: COLUMN psychologist_patient_emergency_contacts.psychologist_patient_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patient_emergency_contacts.psychologist_patient_id IS 'Reference to the psychologist_patients table';
