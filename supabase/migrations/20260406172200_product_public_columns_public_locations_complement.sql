-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:22:00Z

SET check_function_bodies = false;

--
-- Name: COLUMN public_locations.complement; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.public_locations.complement IS 'Address complement (aligned with production schema).';

--
-- Name: public_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.public_profiles (
    id uuid NOT NULL,
    full_name text,
    username text,
    professional_title text,
    crp text,
    crp_state text,
    bio text,
    neighborhood text,
    specialties text[],
    therapeutic_approaches text[],
    session_duration integer,
    session_price integer,
    slug text,
    avatar_path text,
    background_path text,
    social_links jsonb,
    linktree_theme text,
    profile_sections jsonb,
    video_section jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    display_name text,
    tagline text,
    city text,
    state text,
    languages text[],
    academic_timeline jsonb,
    professional_timeline jsonb,
    registered_specialties text[],
    avatar_url text,
    background_url text,
    gallery_photos text[],
    is_public boolean DEFAULT true,
    show_in_marketplace boolean DEFAULT false,
    profile_completed boolean DEFAULT false,
    accepting_new_patients boolean DEFAULT false NOT NULL,
    display_name_linktree text,
    education jsonb,
    certificates jsonb,
    gender text,
    date_of_birth date,
    marital_status text,
    ethnicity text,
    cpf text,
    rqe text,
    linkedin_url text,
    instagram_url text,
    website_url text,
    youtube_url text,
    whatsapp_url text,
    telegram_url text,
    service_values jsonb,
    education_records jsonb,
    CONSTRAINT registered_specialties_limit CHECK ((cardinality(registered_specialties) <= 2))
);

--
-- Name: COLUMN public_profiles.display_name_linktree; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.public_profiles.display_name_linktree IS 'Optional public-facing display name variant used by link pages.';

--
-- Name: COLUMN public_profiles.service_values; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.public_profiles.service_values IS 'Structured pricing/service payload as used in production profile schema.';

--
-- Name: COLUMN public_profiles.education_records; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.public_profiles.education_records IS 'Structured education history records as used in production profile schema.';

--
-- Name: reference_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reference_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category text NOT NULL,
    label_pt text NOT NULL,
    value text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: security_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.security_audit_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    target_type text NOT NULL,
    target_id text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    correlation_id uuid DEFAULT gen_random_uuid() NOT NULL,
    source text DEFAULT 'app'::text NOT NULL
);

--
-- Name: session_billing_dead_letter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_billing_dead_letter (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    psychologist_id uuid NOT NULL,
    error_message text NOT NULL,
    context jsonb DEFAULT '{}'::jsonb NOT NULL,
    attempts integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone
);

--
-- Name: session_reschedule_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_reschedule_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    from_start_time timestamp with time zone NOT NULL,
    to_start_time timestamp with time zone NOT NULL,
    from_duration_minutes integer,
    to_duration_minutes integer,
    reason text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid
);

--
-- Name: session_reschedule_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_reschedule_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    initiated_by uuid,
    responded_by uuid,
    requested_start_time timestamp with time zone,
    requested_end_time timestamp with time zone,
    reason text,
    status public.reschedule_request_status DEFAULT 'pending'::public.reschedule_request_status,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: session_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.session_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text,
    name text DEFAULT 'Sessao'::text NOT NULL,
    default_duration_minutes integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: TABLE session_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.session_types IS 'Catalog of available session types';

--
-- Name: stripe_idempotency_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stripe_idempotency_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    idempotency_key text NOT NULL,
    stripe_event_id text,
    operation text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    request_payload jsonb,
    response_summary jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '30 days'::interval) NOT NULL
);

--
-- Name: TABLE stripe_idempotency_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.stripe_idempotency_log IS 'Idempotency tracking for Stripe webhook processing';

--
-- Name: stripe_webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stripe_webhook_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    stripe_event_id text NOT NULL,
    event_type text NOT NULL,
    stripe_account_id text,
    livemode boolean DEFAULT false NOT NULL,
    payload jsonb NOT NULL,
    received_at timestamp with time zone DEFAULT now(),
    processed_at timestamp with time zone,
    processing_error text
);

--
-- Name: subscription_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscription_plans (
    id text NOT NULL,
    stripe_price_id text,
    stripe_product_id text,
    name text,
    description text,
    amount_cents integer,
    currency text DEFAULT 'brl'::text,
    "interval" text,
    interval_count integer,
    is_active boolean DEFAULT true,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    subscription_plan_id text,
    plan_name text,
    features jsonb DEFAULT '{}'::jsonb
);

--
-- Name: TABLE subscription_plans; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.subscription_plans IS 'Catalog of available subscription plans. Defines base features and limits. Provider-agnostic table name with provider-specific columns.';

--
-- Name: COLUMN subscription_plans.stripe_price_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.subscription_plans.stripe_price_id IS 'The ID of the price/plan in Stripe (Clover v2 API).';

--
-- Name: COLUMN subscription_plans.subscription_plan_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.subscription_plans.subscription_plan_id IS 'Internal slug for the plan (e.g., "basic", "pro", "premium").';

--
-- Name: COLUMN subscription_plans.plan_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.subscription_plans.plan_name IS 'Display name of the plan.';

--
-- Name: COLUMN subscription_plans.features; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.subscription_plans.features IS 'JSONB containing base entitlements and quotas. Example: {"can_use_ai": true, "max_patients": 50}.';

--
-- Name: sync_conflict_resolutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sync_conflict_resolutions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    event_id uuid,
    google_event_id text,
    title text,
    message text,
    conflict_type text NOT NULL,
    fluri_data jsonb,
    google_data jsonb,
    status text DEFAULT 'pending'::text NOT NULL,
    resolution text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    CONSTRAINT sync_conflict_resolutions_conflict_type_check CHECK ((conflict_type = ANY (ARRAY['update'::text, 'delete'::text]))),
    CONSTRAINT sync_conflict_resolutions_resolution_check CHECK ((resolution = ANY (ARRAY['kept_fluri'::text, 'took_google'::text, 'manual'::text]))),
    CONSTRAINT sync_conflict_resolutions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'resolved'::text])))
);

--
-- Name: sync_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sync_locks (
    lock_key text NOT NULL,
    locked_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    locked_by text
);
