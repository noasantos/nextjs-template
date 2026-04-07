-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:43Z

SET check_function_bodies = false;

--
-- Name: validate_weekly_availability_overlaps(uuid, integer, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_weekly_availability_overlaps(p_psychologist_id uuid, p_day_of_week integer, p_intervals jsonb) RETURNS TABLE(has_overlap boolean, overlap_details text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  WITH intervals AS (
    SELECT 
      (value->>'startTime')::time as start_time,
      (value->>'endTime')::time as end_time
    FROM jsonb_array_elements(p_intervals)
  )
  SELECT 
    true,
    format('Overlap between %s-%s and %s-%s', i1.start_time, i1.end_time, i2.start_time, i2.end_time)
  FROM intervals i1
  JOIN intervals i2 ON i1.start_time < i2.end_time AND i2.start_time < i1.end_time
  WHERE i1.start_time != i2.start_time OR i1.end_time != i2.end_time
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::text;
  END IF;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_deletion_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_deletion_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    requested_by uuid NOT NULL,
    reason text,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    approved_at timestamp with time zone,
    processing_started_at timestamp with time zone,
    processed_at timestamp with time zone,
    failed_at timestamp with time zone,
    failure_reason text,
    retention_until timestamp with time zone,
    correlation_id uuid DEFAULT gen_random_uuid() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    cancelled_at timestamp with time zone,
    status public.account_deletion_status DEFAULT 'requested'::public.account_deletion_status NOT NULL
);

--
-- Name: TABLE account_deletion_requests; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.account_deletion_requests IS 'Stores user requests for account deletion, tracking the lifecycle from initial request through approval, processing, and final completion or failure. Includes data retention periods and reasoning for deletion.';

--
-- Name: COLUMN account_deletion_requests.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.id IS 'Unique identifier for the deletion request.';

--
-- Name: COLUMN account_deletion_requests.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.user_id IS 'The ID of the user whose account is being deleted.';

--
-- Name: COLUMN account_deletion_requests.requested_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.requested_by IS 'The ID of the user who initiated the request (can be the user themselves or an admin).';

--
-- Name: COLUMN account_deletion_requests.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.reason IS 'Optional reason provided by the user for deleting their account.';

--
-- Name: COLUMN account_deletion_requests.requested_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.requested_at IS 'Timestamp when the deletion was first requested.';

--
-- Name: COLUMN account_deletion_requests.approved_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.approved_at IS 'Timestamp when the request was approved for processing.';

--
-- Name: COLUMN account_deletion_requests.processing_started_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.processing_started_at IS 'Timestamp when the background deletion process actually started.';

--
-- Name: COLUMN account_deletion_requests.processed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.processed_at IS 'Timestamp when the deletion process was successfully completed.';

--
-- Name: COLUMN account_deletion_requests.failed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.failed_at IS 'Timestamp when the deletion process encountered a terminal error.';

--
-- Name: COLUMN account_deletion_requests.failure_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.failure_reason IS 'Detailed error message if the deletion process failed.';

--
-- Name: COLUMN account_deletion_requests.retention_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.retention_until IS 'Timestamp until which the data must be kept before permanent deletion, for legal or compliance reasons.';

--
-- Name: COLUMN account_deletion_requests.correlation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.correlation_id IS 'Unique ID to correlate this request across distributed systems and logs.';

--
-- Name: COLUMN account_deletion_requests.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.metadata IS 'Flexible JSON storage for additional request context (e.g., IP address, source, etc.).';

--
-- Name: COLUMN account_deletion_requests.cancelled_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.cancelled_at IS 'Timestamp when the deletion request was cancelled by the user or an admin.';

--
-- Name: COLUMN account_deletion_requests.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.account_deletion_requests.status IS 'Current state of the request using a controlled enum (requested, approved, processing, completed, failed, cancelled).';

--
-- Name: assistant_invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assistant_invites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invited_email text,
    expires_at timestamp with time zone NOT NULL,
    accepted_at timestamp with time zone,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    psychologist_id uuid,
    invited_phone text,
    metadata jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT assistant_invites_contact_check CHECK (((invited_email IS NOT NULL) OR (invited_phone IS NOT NULL)))
);

--
-- Name: TABLE assistant_invites; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.assistant_invites IS 'Manages the onboarding process for assistants. Stores invitation tokens sent via email or phone, linked to a specific psychologist. Invites have a deadline (expires_at) and can be revoked manually.';

--
-- Name: COLUMN assistant_invites.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.assistant_invites.id IS 'Unique identifier for the invite (token).';

--
-- Name: COLUMN assistant_invites.invited_email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.assistant_invites.invited_email IS 'Email address where the invitation was sent. Optional if phone is provided.';

--
-- Name: COLUMN assistant_invites.expires_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.assistant_invites.expires_at IS 'Deadline for the invite to be accepted. After this, the token is invalid.';

--
-- Name: COLUMN assistant_invites.accepted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.assistant_invites.accepted_at IS 'Timestamp when the assistant accepted the invitation and was linked to the psychologist.';

--
-- Name: COLUMN assistant_invites.revoked_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.assistant_invites.revoked_at IS 'Timestamp if the psychologist cancelled the invite before it was accepted or expired.';

--
-- Name: COLUMN assistant_invites.psychologist_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.assistant_invites.psychologist_id IS 'The ID of the psychologist who owns the data and is issuing the invitation.';

--
-- Name: COLUMN assistant_invites.invited_phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.assistant_invites.invited_phone IS 'Phone number (WhatsApp) where the invitation was sent. Optional if email is provided.';

--
-- Name: COLUMN assistant_invites.metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.assistant_invites.metadata IS 'Additional context for the invite (e.g., invitation channel, language, etc.).';

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    user_type text,
    table_name text,
    record_id text,
    action text,
    changed_fields jsonb,
    ip_address inet,
    user_agent text,
    correlation_id uuid DEFAULT gen_random_uuid(),
    created_at timestamp with time zone DEFAULT now()
);

--
-- Name: TABLE audit_logs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.audit_logs IS 'Central repository for security and operational auditing. Tracks all changes to sensitive data for LGPD/GDPR compliance. DO NOT MODIFY DIRECTLY - use triggers only.';

--
-- Name: COLUMN audit_logs.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.id IS 'Unique identifier for the audit log entry.';

--
-- Name: COLUMN audit_logs.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.user_id IS 'ID of the user who made the change. Always populated via auth.uid() for user actions or set_config for service-role operations.';

--
-- Name: COLUMN audit_logs.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.user_type IS 'Role of the user (psychologist, admin, assistant, etc.)';

--
-- Name: COLUMN audit_logs.table_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.table_name IS 'Table that was modified';

--
-- Name: COLUMN audit_logs.record_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.record_id IS 'ID of the record that was modified';

--
-- Name: COLUMN audit_logs.action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.action IS 'Operation type: INSERT, UPDATE, DELETE';

--
-- Name: COLUMN audit_logs.changed_fields; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.changed_fields IS 'JSONB containing old/new values and diff';

--
-- Name: COLUMN audit_logs.ip_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.ip_address IS 'IP address of the user (if available)';

--
-- Name: COLUMN audit_logs.user_agent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.user_agent IS 'User agent string (if available)';

--
-- Name: COLUMN audit_logs.correlation_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.correlation_id IS 'UUID for tracing across distributed systems';

--
-- Name: COLUMN audit_logs.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_logs.created_at IS 'Timestamp when the audit log entry was created.';

--
-- Name: availability_exceptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.availability_exceptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    exception_date date NOT NULL,
    is_available boolean DEFAULT false,
    start_time time without time zone,
    end_time time without time zone,
    reason text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

--
-- Name: TABLE availability_exceptions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.availability_exceptions IS 'Overrides for specific dates (holidays, vacations).';

--
-- Name: busy_slots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.busy_slots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    psychologist_id uuid NOT NULL,
    slot_range tstzrange NOT NULL,
    source_type text NOT NULL,
    source_id uuid NOT NULL,
    event_type public.calendar_event_type,
    is_hard_block boolean DEFAULT true NOT NULL,
    title text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT busy_slots_source_type_check CHECK ((source_type = ANY (ARRAY['calendar_event'::text, 'clinical_session'::text, 'series_expansion'::text]))),
    CONSTRAINT valid_slot_range CHECK ((NOT isempty(slot_range)))
);

--
-- Name: TABLE busy_slots; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.busy_slots IS 'Ultimate source of truth for time blocking. Prevents double-booking.';
