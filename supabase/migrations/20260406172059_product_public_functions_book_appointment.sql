-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:20:59Z

SET check_function_bodies = false;

--
-- Name: book_appointment(uuid, uuid, timestamp with time zone, integer, uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.book_appointment(p_psychologist_id uuid, p_patient_client_id uuid, p_start_time timestamp with time zone, p_duration_minutes integer DEFAULT 50, p_service_id uuid DEFAULT NULL::uuid, p_location_id uuid DEFAULT NULL::uuid, p_timezone text DEFAULT 'America/Sao_Paulo'::text, p_title text DEFAULT 'Sessão'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_end_time timestamptz;
  v_event_id uuid;
  v_session_id uuid;
  v_conflict_count integer;
  v_service_name text;
  v_service_price integer;
BEGIN
  v_end_time := p_start_time + (p_duration_minutes || ' minutes')::interval;

  -- Input validation
  IF p_start_time < now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'SLOT_IN_PAST',
      'message', 'Cannot book a slot in the past'
    );
  END IF;

  IF p_duration_minutes < 15 OR p_duration_minutes > 240 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INVALID_DURATION',
      'message', 'Duration must be between 15 and 240 minutes'
    );
  END IF;

  -- Advisory pre-check: is the slot currently free?
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.busy_slots
  WHERE psychologist_id = p_psychologist_id
    AND slot_range && tstzrange(p_start_time, v_end_time, '[)')
    AND is_hard_block = true;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'SLOT_CONFLICT',
      'message', 'The selected time slot conflicts with an existing appointment or block'
    );
  END IF;

  -- Fetch service details if provided
  IF p_service_id IS NOT NULL THEN
    SELECT ps.name, ps.price_cents
    INTO v_service_name, v_service_price
    FROM public.psychologist_services ps
    WHERE ps.id = p_service_id AND ps.psychologist_id = p_psychologist_id;
  END IF;

  -- Create calendar event (trigger will sync to busy_slots → exclusion constraint fires here)
  BEGIN
    INSERT INTO public.calendar_events (
      psychologist_id,
      event_type,
      title,
      start_datetime,
      end_datetime,
      duration_minutes,
      timezone,
      status,
      source
    ) VALUES (
      p_psychologist_id,
      'session',
      COALESCE(p_title, 'Sessão'),
      p_start_time,
      v_end_time,
      p_duration_minutes,
      p_timezone,
      'scheduled',
      'fluri'
    )
    RETURNING id INTO v_event_id;
  EXCEPTION
    WHEN exclusion_violation THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'DOUBLE_BOOKING_PREVENTED',
        'message', 'Another booking was made for this time slot. Please select a different time.'
      );
  END;

  -- Create clinical session
  INSERT INTO public.clinical_sessions (
    psychologist_id,
    psychologist_client_id,
    start_time,
    duration_minutes,
    psychologist_service_id,
    location_id,
    snapshot_service_name,
    snapshot_price_cents,
    status,
    created_by
  ) VALUES (
    p_psychologist_id,
    p_patient_client_id,
    p_start_time,
    p_duration_minutes,
    p_service_id,
    p_location_id,
    v_service_name,
    v_service_price,
    'scheduled',
    auth.uid()
  )
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'event_id', v_event_id,
      'session_id', v_session_id,
      'start_time', p_start_time,
      'end_time', v_end_time,
      'duration_minutes', p_duration_minutes
    )
  );
END;
$$;

--
-- Name: broadcast_subscription_update(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.broadcast_subscription_update(p_therapist_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  
  
  perform pg_notify(
    'subscription_updated',
    json_build_object('psychologist_id', p_therapist_id)::text
  );
end;
$$;

--
-- Name: calculate_cancellation_fee(uuid, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_cancellation_fee(p_psychologist_id uuid, p_session_start_time timestamp with time zone, p_cancellation_time timestamp with time zone DEFAULT now()) RETURNS TABLE(fee_percentage integer, min_notice_hours integer, hours_before_session numeric, policy_applies boolean, fee_amount_cents integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_policy RECORD;
  v_hours_before NUMERIC;
  v_policy_applies BOOLEAN;
BEGIN
  SELECT * INTO v_policy
  FROM public.get_effective_cancellation_policy(p_psychologist_id, p_cancellation_time);
  
  v_hours_before := EXTRACT(EPOCH FROM (p_session_start_time - p_cancellation_time)) / 3600;
  
  v_policy_applies := v_hours_before < v_policy.min_notice_hours;
  
  RETURN QUERY
  SELECT 
    v_policy.fee_percentage,
    v_policy.min_notice_hours,
    v_hours_before,
    v_policy_applies,
    CASE WHEN v_policy_applies THEN v_policy.fee_percentage ELSE 0 END as fee_amount_cents;
END;
$$;

--
-- Name: FUNCTION calculate_cancellation_fee(p_psychologist_id uuid, p_session_start_time timestamp with time zone, p_cancellation_time timestamp with time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.calculate_cancellation_fee(p_psychologist_id uuid, p_session_start_time timestamp with time zone, p_cancellation_time timestamp with time zone) IS 'Calculates the cancellation fee based on the effective policy and time until session';

--
-- Name: calculate_onboarding_progress(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_onboarding_progress(p_psychologist_id uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_completed_steps INTEGER := 0;
  v_state RECORD;
BEGIN
  -- Obter estado atual uma única vez
  SELECT 
    identity_step_completed,
    professional_step_completed,
    payment_step_completed,
    configuration_step_completed,
    profile_step_completed
  INTO v_state
  FROM psychologist_onboarding_state 
  WHERE psychologist_id = p_psychologist_id;
  
  -- Retornar 0 se não houver registro de onboarding
  IF v_state IS NULL THEN
    RETURN 0;
  END IF;
  
  -- Contar passos completos (5 passos, 20% cada)
  IF v_state.identity_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.professional_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.payment_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.configuration_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.profile_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  
  RETURN (v_completed_steps * 100) / 5;
END;
$$;

--
-- Name: FUNCTION calculate_onboarding_progress(p_psychologist_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.calculate_onboarding_progress(p_psychologist_id uuid) IS 'Calcula a porcentagem de progresso do onboarding baseado em 5 passos (20% cada). 
Inclui SET search_path para segurança (fix pós-migração 20260222184642).';

--
-- Name: can_user_access_app(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_user_access_app(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_role public.app_role;
  v_essential_complete BOOLEAN;
BEGIN
  -- Usuário não autenticado = não pode acessar
  IF p_user_id IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Buscar role do usuário
  SELECT role INTO v_role
  FROM public.user_roles
  WHERE user_id = p_user_id;
  
  -- Non-psychologists não têm onboarding, liberar acesso
  IF v_role IS NULL OR v_role != 'psychologist' THEN
    RETURN TRUE;
  END IF;
  
  -- Psicólogos: verificar Fase 1 (Essencial) na view consolidada
  SELECT essential_complete INTO v_essential_complete
  FROM public.psychologist_onboarding_summary
  WHERE psychologist_id = p_user_id;
  
  -- Retornar status (default FALSE se não encontrado)
  RETURN COALESCE(v_essential_complete, FALSE);
END;
$$;

--
-- Name: FUNCTION can_user_access_app(p_user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.can_user_access_app(p_user_id uuid) IS 'SINGLE SOURCE OF TRUTH para controle de acesso ao app.
Retorna TRUE apenas quando Fase 1 (Essencial) está completa:
- identity_step_completed = TRUE
- professional_step_completed = TRUE  
- subscription_status IN (active, trialing) OR payment_step_completed = TRUE

Usar esta função em:
- AuthGuard (no lugar de get_onboarding_status_by_user)
- Proxy/Middleware
- Qualquer verificação de acesso ao app';

--
-- Name: check_calendar_conflicts(uuid, timestamp with time zone, timestamp with time zone, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_calendar_conflicts(p_psychologist_id uuid, p_start_datetime timestamp with time zone, p_end_datetime timestamp with time zone, p_exclude_event_id uuid DEFAULT NULL::uuid) RETURNS TABLE(event_id uuid, event_type public.calendar_event_type, title text, start_datetime timestamp with time zone, end_datetime timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
  SELECT id, event_type, title, start_datetime, end_datetime
  FROM public.calendar_events
  WHERE psychologist_id = p_psychologist_id
    AND status NOT IN ('cancelled', 'rescheduled')
    AND (p_exclude_event_id IS NULL OR id != p_exclude_event_id)
    AND start_datetime < p_end_datetime
    AND end_datetime > p_start_datetime;
$$;
