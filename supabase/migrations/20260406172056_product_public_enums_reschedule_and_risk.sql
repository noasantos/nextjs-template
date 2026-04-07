-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:20:56Z

SET check_function_bodies = false;

--
-- Name: reschedule_initiator; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reschedule_initiator AS ENUM (
    'psychologist',
    'client'
);

--
-- Name: reschedule_request_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reschedule_request_status AS ENUM (
    'pending',
    'accepted',
    'rejected'
);

--
-- Name: risk_level_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.risk_level_type AS ENUM (
    'low',
    'medium',
    'high',
    'critical'
);

--
-- Name: series_exception_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.series_exception_type AS ENUM (
    'cancelled',
    'rescheduled',
    'modified'
);

--
-- Name: session_cancellation_policy_code; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.session_cancellation_policy_code AS ENUM (
    'flexible',
    'standard',
    'strict',
    'non_refundable'
);

--
-- Name: stripe_onboarding_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.stripe_onboarding_status AS ENUM (
    'not_started',
    'pending',
    'complete',
    'restricted',
    'rejected'
);

--
-- Name: supervision_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.supervision_type AS ENUM (
    'giving',
    'receiving'
);

--
-- Name: sync_direction; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sync_direction AS ENUM (
    'fluri_to_google',
    'google_to_fluri'
);

--
-- Name: sync_operation; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sync_operation AS ENUM (
    'create',
    'update',
    'delete'
);

--
-- Name: sync_result_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sync_result_status AS ENUM (
    'success',
    'error',
    'skipped'
);

--
-- Name: timeline_event_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.timeline_event_type AS ENUM (
    'patient_created',
    'patient_updated',
    'patient_archived',
    'patient_unarchived',
    'session_scheduled',
    'session_completed',
    'session_cancelled',
    'session_rescheduled',
    'session_no_show',
    'document_generated',
    'document_uploaded',
    'document_archived',
    'activity_assigned',
    'activity_completed',
    'activity_response_received',
    'activity_archived',
    'charge_created',
    'charge_cancelled',
    'payment_received',
    'payment_processed',
    'payment_overdue',
    'refund_processed',
    'note_added',
    'note_updated',
    'note_archived',
    'consent_signed',
    'invite_sent',
    'invite_reminder_sent',
    'account_linked',
    'condition_added',
    'condition_updated',
    'medication_added',
    'medication_updated',
    'emergency_contact_added',
    'emergency_contact_updated',
    'emergency_contact_removed',
    'label_assigned',
    'label_removed',
    'test_applied',
    'test_result_added',
    'test_archived',
    'guardian_added',
    'guardian_updated',
    'guardian_document_uploaded',
    'guardian_document_validated',
    'status_changed',
    'risk_assessment_updated',
    'relationship_started',
    'relationship_ended'
);

--
-- Name: transaction_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.transaction_type AS ENUM (
    'INCOME',
    'EXPENSE'
);

--
-- Name: accept_assistant_invite(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.accept_assistant_invite(p_user_id uuid, p_email text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_invite public.assistant_invites;
  v_practice_id uuid;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
  END IF;

  SELECT * INTO v_invite
  FROM public.assistant_invites
  WHERE invited_email = lower(trim(p_email))
    AND accepted_at IS NULL
    AND revoked_at IS NULL
    AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_invite.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_pending_invite');
  END IF;

  v_practice_id := v_invite.practice_id;

  INSERT INTO public.practice_memberships (practice_id, user_id, role)
  VALUES (v_practice_id, p_user_id, 'assistant'::public.app_role)
  ON CONFLICT (practice_id, user_id) DO UPDATE SET role = 'assistant'::public.app_role, updated_at = now();

  INSERT INTO public.user_roles (user_id, role)
  VALUES (p_user_id, 'assistant'::public.app_role)
  ON CONFLICT (user_id, role) DO NOTHING;

  INSERT INTO public.assistants (id)
  VALUES (p_user_id)
  ON CONFLICT (id) DO NOTHING;

  UPDATE public.assistant_invites
  SET accepted_at = now(), updated_at = now()
  WHERE id = v_invite.id;

  RETURN jsonb_build_object('success', true, 'practice_id', v_practice_id);
END;
$$;

--
-- Name: acquire_sync_lock(text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.acquire_sync_lock(p_lock_key text, p_ttl_ms integer DEFAULT 60000, p_locked_by text DEFAULT NULL::text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_now timestamptz := now();
  v_expires timestamptz := v_now + make_interval(secs => (p_ttl_ms / 1000.0));
begin
  
  insert into public.sync_locks (lock_key, locked_at, expires_at, locked_by)
  values (p_lock_key, v_now, v_expires, p_locked_by)
  on conflict (lock_key) do nothing;

  
  if found then
    return true;
  end if;

  
  update public.sync_locks
    set locked_at = v_now,
        expires_at = v_expires,
        locked_by = p_locked_by
  where lock_key = p_lock_key
    and expires_at <= v_now;

  return found;
end;
$$;

--
-- Name: auto_update_past_session_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auto_update_past_session_status() RETURNS TABLE(updated_count integer, update_timestamp timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_updated_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  
  
  
  WITH updated_sessions AS (
    UPDATE public.clinical_sessions
    SET 
      status = 'open',
      updated_at = v_timestamp
    WHERE 
      status = 'scheduled'
      AND start_time < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_updated_count
  FROM updated_sessions;
  
  
  IF v_updated_count > 0 THEN
    RAISE NOTICE 'Auto-updated % session(s) from scheduled to open at %', 
      v_updated_count, v_timestamp;
  END IF;
  
  
  RETURN QUERY SELECT v_updated_count, v_timestamp;
END;
$$;
