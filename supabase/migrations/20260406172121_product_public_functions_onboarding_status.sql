-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:21Z

SET check_function_bodies = false;

--
-- Name: get_onboarding_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_onboarding_status() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  p_user_id uuid;
  p_role public.app_role;
  p_status boolean;
begin
  
  p_user_id := auth.uid();
  
  if p_user_id is null then
    return false;
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return true;
  end if;
  
  
  select onboarding_completed into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, false);
end;
$$;

--
-- Name: get_onboarding_status_by_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_onboarding_status_by_user(p_user_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Delegar para a função única de controle de acesso
  RETURN public.can_user_access_app(p_user_id);
END;
$$;

--
-- Name: FUNCTION get_onboarding_status_by_user(p_user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_onboarding_status_by_user(p_user_id uuid) IS 'DEPRECATED: Use can_user_access_app() para nova implementação.
Mantida para compatibilidade com código existente.';

--
-- Name: get_onboarding_status_v2(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_onboarding_status_v2(p_user_id uuid DEFAULT NULL::uuid) RETURNS TABLE(essential_complete boolean, fully_complete boolean, completion_percentage integer, current_step integer, total_steps integer, next_pending_step text, payment_completed boolean, identity_completed boolean, professional_completed boolean, configuration_completed boolean, profile_completed boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Usar user_id passado ou o current_user
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 
      FALSE, FALSE, 0, 1, 5, 
      'subscription'::TEXT, 
      FALSE, FALSE, FALSE, FALSE, FALSE;
    RETURN;
  END IF;
  
  -- Garantir que registro existe
  INSERT INTO public.psychologist_onboarding_state (psychologist_id)
  VALUES (v_user_id)
  ON CONFLICT (psychologist_id) DO NOTHING;
  
  -- Atualizar progresso antes de retornar
  PERFORM public.calculate_onboarding_progress(v_user_id);
  
  RETURN QUERY
  SELECT 
    pos.essential_complete,
    pos.fully_complete,
    pos.completion_percentage,
    pos.current_step,
    pos.total_steps,
    pos.next_pending_step,
    pos.payment_step_completed,
    pos.identity_step_completed,
    pos.professional_step_completed,
    pos.configuration_step_completed,
    pos.profile_step_completed
  FROM public.psychologist_onboarding_summary pos
  WHERE pos.psychologist_id = v_user_id;
END;
$$;

--
-- Name: FUNCTION get_onboarding_status_v2(p_user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_onboarding_status_v2(p_user_id uuid) IS 'Retorna o status completo do onboarding do usuário (v2: usa configuration em vez de readiness)';

--
-- Name: get_psychologist_availability(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--


CREATE FUNCTION public.get_psychologist_availability(p_psychologist_id uuid, p_start_date date, p_end_date date) RETURNS TABLE(date date, day_of_week integer, start_time time without time zone, end_time time without time zone, location_id uuid, delivery_mode public.delivery_mode, available_for_first_appointment boolean, is_exception boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with days as (
    select gs::date as slot_date
    from generate_series(p_start_date, p_end_date, interval '1 day') as gs
  ),
  base_slots as (
    select
      d.slot_date as date,
      pws.day_of_week,
      pws.start_time,
      pws.end_time,
      pws.location_id,
      pws.delivery_mode,
      coalesce(pws.available_for_first_appointment, true) as available_for_first_appointment,
      false as is_exception
    from days d
    join public.psychologist_weekly_schedules pws
      on pws.psychologist_id = p_psychologist_id
      and pws.is_active = true
      and pws.day_of_week = extract(dow from d.slot_date)::int
      and (pws.effective_start is null or pws.effective_start <= d.slot_date)
      and (pws.effective_end is null or pws.effective_end >= d.slot_date)
    left join public.availability_exceptions ae
      on ae.psychologist_id = p_psychologist_id
      and ae.exception_date = d.slot_date
    where coalesce(ae.is_available, true) = true
  ),
  exception_slots as (
    select
      ae.exception_date as date,
      extract(dow from ae.exception_date)::int as day_of_week,
      ae.start_time,
      ae.end_time,
      null::uuid as location_id,
      null::public.delivery_mode as delivery_mode,
      true as available_for_first_appointment,
      true as is_exception
    from public.availability_exceptions ae
    where ae.psychologist_id = p_psychologist_id
      and ae.exception_date between p_start_date and p_end_date
      and ae.is_available = true
      and ae.start_time is not null
      and ae.end_time is not null
  )
  select * from base_slots
  union all
  select * from exception_slots
  order by date, start_time;
$$;

--
-- Name: get_psychologist_ids_for_patient(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_psychologist_ids_for_patient(p_patient_id uuid) RETURNS SETOF uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select psychologist_id
  from public.psychologist_clients
  where patient_id = p_patient_id
    and status = 'active';
$$;

--
-- Name: get_psychologist_linktree_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_psychologist_linktree_data(p_psychologist_id uuid) RETURNS TABLE(id uuid, title text, url text, is_active boolean, sort_order integer, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO ''
    AS $$
    SELECT
        id,
        title,
        url,
        is_active,
        sort_order,
        created_at,
        updated_at
    FROM public.public_linktree_links
    WHERE psychologist_id = p_psychologist_id
    ORDER BY sort_order ASC, created_at ASC;
$$;

--
-- Name: get_public_psychologist_by_username(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_public_psychologist_by_username(p_username text) RETURNS TABLE(id uuid, full_name text, avatar_url text, crp text, crp_state text, bio text, specialties jsonb)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.full_name, p.avatar_url, p.crp, p.crp_state, pp.bio, pp.specialties::jsonb
  FROM user_psychologists p
  LEFT JOIN psychologist_profiles pp ON p.id = pp.id
  WHERE p.username = p_username;
END;
$$;

--
-- Name: FUNCTION get_public_psychologist_by_username(p_username text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_public_psychologist_by_username(p_username text) IS 'Retrieves public psychologist profile by username';

--
-- Name: get_record_audit_history(text, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_record_audit_history(p_table_name text, p_record_id text, p_limit integer DEFAULT 50) RETURNS TABLE(action text, user_id uuid, user_type text, changed_fields jsonb, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    al.action,
    al.user_id,
    al.user_type,
    al.changed_fields,
    al.created_at
  FROM public.audit_logs al
  WHERE al.table_name = p_table_name
    AND al.record_id = p_record_id
  ORDER BY al.created_at DESC
  LIMIT p_limit;
END;
$$;

--
-- Name: FUNCTION get_record_audit_history(p_table_name text, p_record_id text, p_limit integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_record_audit_history(p_table_name text, p_record_id text, p_limit integer) IS 'Get complete audit history for a specific record. Useful for data lineage and compliance investigations.';

--
-- Name: get_sessions_needing_reminders(text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_sessions_needing_reminders(p_reminder_type text, p_batch_size integer DEFAULT 100) RETURNS TABLE(session_id uuid, psychologist_id uuid, patient_id uuid, session_start_time timestamp with time zone, patient_phone text, patient_email text, reminder_hours_before integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_hours_before INTEGER;
BEGIN
  v_hours_before := CASE p_reminder_type
    WHEN '24h_before' THEN 24
    WHEN '1h_before' THEN 1
    ELSE 24
  END;
  
  RETURN QUERY
  SELECT 
    pcs.id as session_id, pcs.psychologist_id, pcs.psychologist_patient_id as patient_id,
    pcs.start_time as session_start_time, pp.manual_phone as patient_phone, pp.manual_email as patient_email,
    v_hours_before as reminder_hours_before
  FROM public.psychologist_clinical_sessions pcs
  JOIN public.psychologist_patients pp ON pp.id = pcs.psychologist_patient_id
  WHERE pcs.start_time BETWEEN NOW() + INTERVAL '1 minute' AND NOW() + (v_hours_before || ' hours')::INTERVAL
    AND pcs.attendance_confirmed IS NULL
    AND (pcs.automation_metadata IS NULL
      OR NOT (pcs.automation_metadata ? p_reminder_type)
      OR (pcs.automation_metadata->p_reminder_type->>'sent_at') IS NULL)
  ORDER BY pcs.start_time ASC
  LIMIT p_batch_size;
END;
$$;

--
-- Name: FUNCTION get_sessions_needing_reminders(p_reminder_type text, p_batch_size integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_sessions_needing_reminders(p_reminder_type text, p_batch_size integer) IS 'Returns sessions that need reminders sent (24h_before, 1h_before, etc.)';

--
-- Name: get_subscription_status_by_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_subscription_status_by_user(p_user_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  p_role public.app_role;
  p_status text;
begin
  if p_user_id is null then
    return 'none';
  end if;

  select role into p_role
  from public.user_roles
  where user_id = p_user_id;

  if p_role is null or p_role != 'psychologist' then
    return 'none';
  end if;

  select subscription_status into p_status
  from public.user_psychologists
  where id = p_user_id;

  return coalesce(p_status, 'none');
end;
$$;
