-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:27Z

SET check_function_bodies = false;

--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'admin'
  );
$$;

--
-- Name: is_admin_or_own_psychologist(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin_or_own_psychologist(p_psychologist_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select 
    public.is_admin() or 
    p_psychologist_id = (select auth.uid());
$$;

--
-- Name: is_assistant(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_assistant() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'assistant'
  );
$$;

--
-- Name: is_linked_to_psychologist_client(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_linked_to_psychologist_client(p_psychologist_client_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.psychologist_clients
    where id = p_psychologist_client_id
      and patient_id = (select auth.uid())
  );
$$;

--
-- Name: is_onboarding_essential_complete(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_onboarding_essential_complete(p_psychologist_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_has_subscription BOOLEAN;
  v_state RECORD;
BEGIN
  -- Buscar estado do onboarding
  SELECT * INTO v_state 
  FROM public.psychologist_onboarding_state 
  WHERE psychologist_id = p_psychologist_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Verificar se tem subscription ativa
  SELECT subscription_status IN ('active', 'trialing')
  INTO v_has_subscription
  FROM public.user_psychologists
  WHERE id = p_psychologist_id;
  
  -- FASE 1 (ESSENCIAL): identity + professional + (payment OU subscription)
  RETURN (
    v_state.identity_step_completed 
    AND v_state.professional_step_completed 
    AND (COALESCE(v_has_subscription, FALSE) OR v_state.payment_step_completed)
  );
END;
$$;

--
-- Name: FUNCTION is_onboarding_essential_complete(p_psychologist_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_onboarding_essential_complete(p_psychologist_id uuid) IS 'Verifica se Fase 1 (Essencial) está completa: identity + professional + payment/subscription.
Retorna TRUE apenas quando TODOS os 3 componentes essenciais estão completos.';

--
-- Name: is_onboarding_fully_complete(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_onboarding_fully_complete(p_psychologist_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_state RECORD;
BEGIN
  SELECT * INTO v_state
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = p_psychologist_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- All 5 steps must be complete
  RETURN (
    v_state.identity_step_completed 
    AND v_state.professional_step_completed 
    AND v_state.payment_step_completed
    AND v_state.configuration_step_completed
    AND v_state.profile_step_completed
  );
END;
$$;

--
-- Name: FUNCTION is_onboarding_fully_complete(p_psychologist_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_onboarding_fully_complete(p_psychologist_id uuid) IS 'Returns TRUE when all 5 onboarding steps are complete (identity + professional + payment + configuration + profile).';

--
-- Name: is_own_patient_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_own_patient_data(p_patient_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select p_patient_id = (select auth.uid());
$$;

--
-- Name: is_own_psychologist_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_own_psychologist_data(p_psychologist_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select p_psychologist_id = (select auth.uid());
$$;

--
-- Name: is_patient(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_patient() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'patient'
  );
$$;

--
-- Name: is_profile_public(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_profile_public(p_psychologist_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  select exists (
    select 1
    from public.public_profiles pp
    where pp.id = p_psychologist_id
      and pp.is_public = true
      and coalesce(pp.show_in_marketplace, true) = true
      and pp.display_name is not null
  );
$$;

--
-- Name: FUNCTION is_profile_public(p_psychologist_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_profile_public(p_psychologist_id uuid) IS 'Returns true if the psychologist has a public profile (public_profiles) that is public and has display_name.';

--
-- Name: is_psychologist(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_psychologist() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'psychologist'
  );
$$;

--
-- Name: is_psychologist_or_linked_patient(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_psychologist_or_linked_patient(p_psychologist_id uuid, p_psychologist_client_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select 
    p_psychologist_id = (select auth.uid()) or
    public.is_linked_to_psychologist_client(p_psychologist_client_id);
$$;

--
-- Name: is_webhook_event_processed(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_webhook_event_processed(p_event_id text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.webhook_events
    where event_id = p_event_id
  );
$$;

--
-- Name: log_security_audit_event(uuid, text, text, text, jsonb, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_security_audit_event(p_actor_id uuid, p_action text, p_target_type text, p_target_id text, p_metadata jsonb DEFAULT '{}'::jsonb, p_correlation_id uuid DEFAULT gen_random_uuid(), p_source text DEFAULT 'app'::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_event_id uuid;
BEGIN
  INSERT INTO public.security_audit_events (
    actor_id,
    action,
    target_type,
    target_id,
    metadata,
    correlation_id,
    source
  )
  VALUES (
    p_actor_id,
    p_action,
    p_target_type,
    p_target_id,
    COALESCE(p_metadata, '{}'::jsonb),
    COALESCE(p_correlation_id, gen_random_uuid()),
    COALESCE(p_source, 'app')
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;

--
-- Name: mark_reminder_sent(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_reminder_sent(p_session_id uuid, p_reminder_type text, p_channel text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  UPDATE public.psychologist_clinical_sessions
  SET 
    automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
      p_reminder_type, jsonb_build_object('sent_at', NOW(), 'channel', p_channel, 'status', 'sent')
    ),
    reminder_sent_at = CASE WHEN p_reminder_type = '24h_before' THEN NOW() ELSE reminder_sent_at END
  WHERE id = p_session_id;
  
  RETURN FOUND;
END;
$$;

--
-- Name: FUNCTION mark_reminder_sent(p_session_id uuid, p_reminder_type text, p_channel text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.mark_reminder_sent(p_session_id uuid, p_reminder_type text, p_channel text) IS 'Marks a reminder as sent in the session automation_metadata';
