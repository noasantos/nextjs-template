-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:41Z

SET check_function_bodies = false;

--
-- Name: trigger_update_onboarding_progress(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_update_onboarding_progress() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  NEW.completion_percentage := public.calculate_onboarding_progress(NEW.psychologist_id);
  
  IF NEW.completion_percentage = 100 AND NEW.onboarding_completed_at IS NULL THEN
    NEW.onboarding_completed_at := NOW();
  END IF;

  RETURN NEW;
END;
$$;

--
-- Name: update_attendance_confirmation(uuid, boolean, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_attendance_confirmation(p_session_id uuid, p_confirmed boolean, p_confirmation_source text, p_confirmed_by uuid DEFAULT NULL::uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  UPDATE public.psychologist_clinical_sessions
  SET attendance_confirmed = p_confirmed, confirmation_sent_at = NOW(),
    automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
      'attendance_confirmation', jsonb_build_object(
        'confirmed', p_confirmed, 'confirmed_at', NOW(), 'source', p_confirmation_source, 'confirmed_by', p_confirmed_by
      )
    )
  WHERE id = p_session_id;
  
  RETURN FOUND;
END;
$$;

--
-- Name: FUNCTION update_attendance_confirmation(p_session_id uuid, p_confirmed boolean, p_confirmation_source text, p_confirmed_by uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.update_attendance_confirmation(p_session_id uuid, p_confirmed boolean, p_confirmation_source text, p_confirmed_by uuid) IS 'Updates attendance confirmation with source tracking';

--
-- Name: update_calendar_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_calendar_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

--
-- Name: update_clinical_sessions_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_clinical_sessions_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;

--
-- Name: update_onboarding_progress(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_onboarding_progress() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  v_progress INTEGER;
  v_new_step INTEGER;
BEGIN
  -- Calculate progress
  v_progress := calculate_onboarding_progress(NEW.psychologist_id);
  
  -- Determine current step based on completion status
  -- Order: identity (1) → professional (2) → payment (3) → configuration (4) → profile (5)
  IF NOT NEW.identity_step_completed THEN
    v_new_step := 1;
  ELSIF NOT NEW.professional_step_completed THEN
    v_new_step := 2;
  ELSIF NOT NEW.payment_step_completed THEN
    v_new_step := 3;
  ELSIF NOT NEW.configuration_step_completed THEN
    v_new_step := 4;
  ELSIF NOT NEW.profile_step_completed THEN
    v_new_step := 5;
  ELSE
    v_new_step := 6; -- complete
  END IF;
  
  -- Update calculated fields only if changed
  IF NEW.completion_percentage IS DISTINCT FROM v_progress 
     OR NEW.current_step IS DISTINCT FROM v_new_step THEN
    NEW.completion_percentage := v_progress;
    NEW.current_step := v_new_step;
  END IF;
  
  RETURN NEW;
END;
$$;

--
-- Name: update_patient_session_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_patient_session_stats() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    UPDATE public.psychologist_patients
    SET 
      last_session_date = NEW.start_time::date,
      total_sessions_count = COALESCE(total_sessions_count, 0) + 1,
      updated_at = NOW()
    WHERE id = NEW.psychologist_patient_id;
  END IF;
  RETURN NEW;
END;
$$;

--
-- Name: update_psychologist_availability_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_psychologist_availability_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;

--
-- Name: update_psychologist_clients_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_psychologist_clients_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;

--
-- Name: update_psychologist_subscriptions_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_psychologist_subscriptions_trigger() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at = now();
  
  new.has_active_subscription = (
    new.status in ('active', 'trialing') and 
    (new.current_period_end is null or new.current_period_end > now())
  );
  return new;
end;
$$;

--
-- Name: upsert_weekly_availability(uuid, integer, boolean, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upsert_weekly_availability(p_psychologist_id uuid, p_day_of_week integer, p_is_active boolean, p_intervals jsonb DEFAULT '[]'::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_interval jsonb;
  v_start_time time;
  v_end_time time;
  v_location_id uuid;
  v_delivery_mode public.delivery_mode;
  v_available_for_first boolean;
BEGIN
  
  IF p_day_of_week < 0 OR p_day_of_week > 6 THEN
    RAISE EXCEPTION 'Invalid day_of_week: must be between 0 and 6';
  END IF;
  
  
  IF (SELECT auth.uid()) != p_psychologist_id THEN
    RAISE EXCEPTION 'Unauthorized: can only modify own availability';
  END IF;
  
  
  UPDATE public.psychologist_availability
  SET 
    is_active = false,
    updated_at = now()
  WHERE psychologist_id = p_psychologist_id
    AND day_of_week = p_day_of_week;
  
  
  IF p_is_active THEN
    FOR v_interval IN SELECT * FROM jsonb_array_elements(p_intervals)
    LOOP
      
      v_start_time := (v_interval->>'startTime')::time;
      v_end_time := (v_interval->>'endTime')::time;
      v_location_id := (v_interval->>'locationId')::uuid;
      v_delivery_mode := COALESCE(
        (v_interval->>'deliveryMode')::public.delivery_mode,
        'hybrid'::public.delivery_mode
      );
      v_available_for_first := COALESCE(
        (v_interval->>'availableForFirstAppointment')::boolean,
        true
      );
      
      
      IF v_end_time <= v_start_time THEN
        RAISE EXCEPTION 'Invalid time range: end_time must be after start_time';
      END IF;
      
      
      INSERT INTO public.psychologist_availability (
        psychologist_id,
        day_of_week,
        start_time,
        end_time,
        location_id,
        delivery_mode,
        available_for_first_appointment,
        is_active,
        effective_start,
        effective_end,
        daily_appointment_limit
      )
      VALUES (
        p_psychologist_id,
        p_day_of_week,
        v_start_time,
        v_end_time,
        v_location_id,
        v_delivery_mode,
        v_available_for_first,
        true,
        NULL,
        NULL,
        (v_interval->>'dailyAppointmentLimit')::integer
      )
      ON CONFLICT (psychologist_id, day_of_week, start_time) 
      DO UPDATE SET
        end_time = EXCLUDED.end_time,
        location_id = EXCLUDED.location_id,
        delivery_mode = EXCLUDED.delivery_mode,
        available_for_first_appointment = EXCLUDED.available_for_first_appointment,
        is_active = EXCLUDED.is_active,
        daily_appointment_limit = EXCLUDED.daily_appointment_limit,
        updated_at = now();
    END LOOP;
  END IF;
END;
$$;

--
-- Name: user_has_role(uuid, public.app_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_has_role(p_user_id uuid, p_role public.app_role) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.user_roles
    where user_id = p_user_id
      and role = p_role
  );
$$;

--
-- Name: validate_financial_entry_category(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_financial_entry_category() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_category_type public.transaction_type;
BEGIN
  IF NEW.transaction_category_id IS NOT NULL THEN
    SELECT type INTO v_category_type
    FROM public.financial_transaction_categories
    WHERE id = NEW.transaction_category_id;
    
    IF v_category_type IS NULL THEN
      RAISE EXCEPTION 'Categoria não encontrada';
    END IF;
    
    IF (NEW.type = 'income' AND v_category_type != 'INCOME') OR
       (NEW.type = 'expense' AND v_category_type != 'EXPENSE') THEN
      RAISE EXCEPTION 'Categoria incompatível com o tipo de lançamento';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;
