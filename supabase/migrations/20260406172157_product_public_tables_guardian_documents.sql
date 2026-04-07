-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:57Z

SET check_function_bodies = false;

--
-- Name: psychologist_patient_guardian_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patient_guardian_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    guardian_id uuid,
    patient_id uuid,
    file_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    title text NOT NULL,
    document_type text NOT NULL,
    description text,
    file_name text NOT NULL,
    file_size integer,
    mime_type text,
    uploaded_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    status text DEFAULT 'active'::text NOT NULL,
    CONSTRAINT psychologist_patient_guardian_documents_document_type_check CHECK ((document_type = ANY (ARRAY['power_of_attorney'::text, 'custody'::text, 'authorization'::text, 'id_document'::text, 'consent'::text, 'other'::text]))),
    CONSTRAINT psychologist_patient_guardian_documents_status_check CHECK ((status = ANY (ARRAY['active'::text, 'expired'::text, 'revoked'::text])))
);

--
-- Name: psychologist_patient_guardians; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patient_guardians (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    patient_id uuid,
    name text,
    relationship text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    full_name text,
    guardian_type text,
    phone text,
    email text,
    cpf text,
    rg text,
    date_of_birth date,
    street text,
    number text,
    complement text,
    neighborhood text,
    city text,
    state text,
    postal_code text,
    country text DEFAULT 'Brasil'::text,
    status text DEFAULT 'active'::text
);

--
-- Name: psychologist_patient_medical_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patient_medical_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_patient_id uuid,
    kind public.medical_item_kind,
    name text,
    icd10_code text,
    dosage text,
    frequency text,
    notes text,
    is_active boolean DEFAULT true,
    diagnosed_date date,
    item_kind public.medical_item_kind,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    start_date date,
    end_date date
);

--
-- Name: COLUMN psychologist_patient_medical_items.psychologist_patient_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patient_medical_items.psychologist_patient_id IS 'Reference to the psychologist_patients table';

--
-- Name: psychologist_patient_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_patient_services (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_patient_id uuid NOT NULL,
    service_id uuid,
    price_cents integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: COLUMN psychologist_patient_services.psychologist_patient_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_patient_services.psychologist_patient_id IS 'Reference to the psychologist_patients table';

--
-- Name: psychologist_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_preferences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    notifications_email_reminders boolean DEFAULT true,
    notifications_whatsapp_reminders boolean DEFAULT true,
    notifications_billing_alerts boolean DEFAULT true,
    notifications_payment_receipts boolean DEFAULT true,
    notifications_security_alerts boolean DEFAULT true,
    notifications_marketing boolean DEFAULT false,
    preferences jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: psychologist_preferences_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_preferences_audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    old_values jsonb,
    new_values jsonb,
    action text,
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: psychologist_quick_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_quick_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    title text NOT NULL,
    priority text DEFAULT 'none'::text NOT NULL,
    due_date date,
    is_completed boolean DEFAULT false NOT NULL,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT psychologist_quick_notes_priority_check CHECK ((priority = ANY (ARRAY['none'::text, 'low'::text, 'medium'::text, 'high'::text])))
);

--
-- Name: psychologist_session_cancellation_policy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_session_cancellation_policy (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    policy_code public.cancellation_policy_code,
    effective_from timestamp with time zone DEFAULT now(),
    cancellation_window_hours integer,
    penalty_percent integer,
    effective_until timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: TABLE psychologist_session_cancellation_policy; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.psychologist_session_cancellation_policy IS 'Versioned cancellation policies for psychologists. Each change creates a new record with effective_from timestamp. The trigger automatically closes the previous policy.';

--
-- Name: COLUMN psychologist_session_cancellation_policy.policy_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_session_cancellation_policy.policy_code IS 'Reference to the policy type (flexible, standard, strict) from reference_values';

--
-- Name: COLUMN psychologist_session_cancellation_policy.effective_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_session_cancellation_policy.effective_from IS 'When this policy version became active';

--
-- Name: COLUMN psychologist_session_cancellation_policy.effective_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_session_cancellation_policy.effective_until IS 'When this policy version was superseded (NULL if currently active)';

--
-- Name: psychologist_stripe_connect; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_stripe_connect (
    psychologist_id uuid NOT NULL,
    stripe_account_id text NOT NULL,
    onboarding_status public.stripe_onboarding_status DEFAULT 'not_started'::public.stripe_onboarding_status NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: psychologist_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psychologist_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    therapist_id uuid,
    psychologist_id uuid,
    subscription_plan_id text,
    stripe_subscription_id text,
    stripe_price_id text,
    status text,
    trial_end timestamp with time zone,
    current_period_start timestamp with time zone,
    current_period_end timestamp with time zone,
    cancel_at_period_end boolean DEFAULT false,
    has_active_subscription boolean DEFAULT false,
    metadata jsonb DEFAULT '{}'::jsonb,
    updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: TABLE psychologist_subscriptions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.psychologist_subscriptions IS 'Current subscription state for each psychologist. Only one record per user. References Stripe Clover v2 IDs.';

--
-- Name: COLUMN psychologist_subscriptions.psychologist_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_subscriptions.psychologist_id IS 'The ID of the psychologist who owns this subscription.';

--
-- Name: COLUMN psychologist_subscriptions.stripe_subscription_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_subscriptions.stripe_subscription_id IS 'The subscription identifier in Stripe (Clover v2 API).';

--
-- Name: COLUMN psychologist_subscriptions.stripe_price_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_subscriptions.stripe_price_id IS 'The current price/plan identifier in Stripe.';

--
-- Name: COLUMN psychologist_subscriptions.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_subscriptions.status IS 'Current status of the subscription (e.g., active, trialing, past_due, canceled).';

--
-- Name: COLUMN psychologist_subscriptions.has_active_subscription; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_subscriptions.has_active_subscription IS 'Boolean flag for quick access check (true if status is active or trialing).';

--
-- Name: COLUMN psychologist_subscriptions.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.psychologist_subscriptions.metadata IS 'Used for specific overrides. Schema: {"overrides": {"permissions": ["extra_feat"], "quotas": {"max_patients": 100}}}.';

--
-- Name: public_client_checkout_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_client_checkout_intents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    psychologist_patient_id uuid,
    charge_id uuid,
    session_id uuid,
    stripe_checkout_session_id text,
    stripe_payment_intent_id text,
    stripe_charge_id text,
    stripe_transfer_id text,
    stripe_refund_id text,
    amount_cents integer NOT NULL,
    currency text NOT NULL,
    application_fee_cents integer,
    status public.marketplace_payment_status DEFAULT 'requires_payment_method'::public.marketplace_payment_status NOT NULL,
    livemode boolean DEFAULT false NOT NULL,
    idempotency_key text,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: COLUMN public_client_checkout_intents.psychologist_patient_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.public_client_checkout_intents.psychologist_patient_id IS 'Reference to the psychologist_patients table';

--
-- Name: public_linktree_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_linktree_links (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    title text DEFAULT 'Link'::text NOT NULL,
    url text DEFAULT '#'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: TABLE public_linktree_links; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.public_linktree_links IS 'Links for psychologist public profiles (linktree). Uses sort_order for ordering.';

--
-- Name: public_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_locations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    name text,
    street text,
    number text,
    neighborhood text,
    city text,
    state text,
    postal_code text,
    country text,
    latitude double precision,
    longitude double precision,
    is_primary boolean DEFAULT false,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    complement text
);
