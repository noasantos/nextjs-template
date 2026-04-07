-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:24Z

SET check_function_bodies = false;

--
-- Name: get_upcoming_exceptions(uuid, date, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_upcoming_exceptions(p_psychologist_id uuid, p_from_date date DEFAULT CURRENT_DATE, p_limit integer DEFAULT 50) RETURNS TABLE(id uuid, exception_date date, is_available boolean, start_time time without time zone, end_time time without time zone, reason text, created_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ae.id,
    ae.exception_date,
    ae.is_available,
    ae.start_time,
    ae.end_time,
    ae.reason,
    ae.created_at
  FROM public.availability_exceptions ae
  WHERE ae.psychologist_id = p_psychologist_id
    AND ae.exception_date >= p_from_date
  ORDER BY ae.exception_date, ae.start_time NULLS FIRST
  LIMIT p_limit;
END;
$$;

--
-- Name: get_user_by_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_by_email(email_input text) RETURNS TABLE(id uuid, email text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  RETURN QUERY
  SELECT au.id, au.email::text
  FROM auth.users au
  WHERE lower(au.email) = lower(email_input);
END;
$$;

--
-- Name: get_user_id_by_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_id_by_email(p_email text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'auth', 'public'
    AS $$
declare
  target_id uuid;
begin
  select id into target_id 
  from auth.users 
  where auth.users.email = p_email 
  limit 1;
  
  return target_id;
end;
$$;

--
-- Name: get_user_role(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_role(p_user_id uuid) RETURNS public.app_role
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select role
  from public.user_roles
  where user_id = p_user_id
  limit 1;
$$;

--
-- Name: get_user_subscription_status(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_user_subscription_status(p_user_id uuid) RETURNS TABLE(status text, is_active boolean, has_essential_access boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(up.subscription_status, 'inactive')::TEXT as status,
    COALESCE(up.subscription_status IN ('active', 'trialing'), FALSE) as is_active,
    pos.essential_complete as has_essential_access
  FROM public.psychologist_onboarding_summary pos
  LEFT JOIN public.user_psychologists up ON up.id = pos.psychologist_id
  WHERE pos.psychologist_id = p_user_id;
END;
$$;

--
-- Name: FUNCTION get_user_subscription_status(p_user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_user_subscription_status(p_user_id uuid) IS 'Retorna detalhes da subscription do usuário.
- status: status bruto da subscription
- is_active: TRUE se active/trialing
- has_essential_access: TRUE se pode acessar app (Fase 1 completa)

Usar para:
- Mostrar status de pagamento na UI
- Verificar se usuário precisa renovar
- NOTA: Para controle de acesso, usar can_user_access_app()';

--
-- Name: get_weekly_availability_config(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_weekly_availability_config(p_psychologist_id uuid) RETURNS TABLE(day_of_week integer, intervals jsonb, is_active boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pa.day_of_week,
    jsonb_agg(
      jsonb_build_object(
        'id', pa.id,
        'startTime', pa.start_time::text,
        'endTime', pa.end_time::text,
        'locationId', pa.location_id,
        'deliveryMode', pa.delivery_mode,
        'availableForFirstAppointment', pa.available_for_first_appointment,
        'dailyAppointmentLimit', pa.daily_appointment_limit
      ) ORDER BY pa.start_time
    ) as intervals,
    bool_or(pa.is_active) as is_active
  FROM public.psychologist_availability pa
  WHERE pa.psychologist_id = p_psychologist_id
    AND pa.is_active = true
    AND (pa.effective_start IS NULL OR pa.effective_start <= CURRENT_DATE)
    AND (pa.effective_end IS NULL OR pa.effective_end >= CURRENT_DATE)
  GROUP BY pa.day_of_week
  ORDER BY pa.day_of_week;
END;
$$;

--
-- Name: handle_new_psychologist(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_psychologist() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  IF NEW.role = 'psychologist' THEN
    INSERT INTO public.user_psychologists (id)
    VALUES (NEW.user_id)
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

--
-- Name: FUNCTION handle_new_psychologist(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.handle_new_psychologist() IS 'Trigger function to create psychologist record on new user_roles insert';

--
-- Name: handle_new_session_charge(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_session_charge() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF current_setting('app.fluri.skip_charge_triggers', true) = 'on' THEN
    RETURN NEW;
  END IF;

  PERFORM public.create_session_charge_if_due(
    NEW.id,
    NEW.psychologist_id,
    7,
    false,
    format('charge:session:%s:v1', NEW.id)
  );

  RETURN NEW;
END;
$$;

--
-- Name: handle_session_update_charge(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_session_update_charge() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF current_setting('app.fluri.skip_charge_triggers', true) = 'on' THEN
    RETURN NEW;
  END IF;

  IF NEW.start_time IS DISTINCT FROM OLD.start_time
     OR NEW.snapshot_price_cents IS DISTINCT FROM OLD.snapshot_price_cents
     OR NEW.snapshot_service_name IS DISTINCT FROM OLD.snapshot_service_name
     OR NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.create_session_charge_if_due(
      NEW.id,
      NEW.psychologist_id,
      7,
      false,
      format('charge:session:%s:v1', NEW.id)
    );
  END IF;

  RETURN NEW;
END;
$$;

--
-- Name: handle_stripe_subscription_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_stripe_subscription_update() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_psychologist_id UUID;
BEGIN
    v_psychologist_id := (NEW.metadata->>'psychologist_id')::UUID;
    
    IF v_psychologist_id IS NULL THEN
        SELECT id INTO v_psychologist_id
        FROM public.psychologists
        WHERE stripe_customer_id = NEW.customer;
    END IF;

    IF v_psychologist_id IS NOT NULL THEN
        UPDATE public.psychologists
        SET subscription_status = NEW.status, stripe_subscription_id = NEW.id, updated_at = NOW()
        WHERE id = v_psychologist_id;
        
        UPDATE auth.users
        SET raw_app_meta_data = jsonb_set(COALESCE(raw_app_meta_data, '{}'::jsonb), '{subscription_status}', to_jsonb(NEW.status)),
            updated_at = NOW()
        WHERE id = v_psychologist_id;
    END IF;

    RETURN NEW;
END;
$$;

--
-- Name: FUNCTION handle_stripe_subscription_update(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.handle_stripe_subscription_update() IS 'Atualiza subscription_status e stripe_subscription_id em psychologists quando o Stripe Sync Engine sincroniza. 
IMPORTANTE: Não atualiza onboarding_completed - onboarding é completado pelo wizard em completeOnboarding(), não pelo pagamento.';

--
-- Name: handle_user_preferences_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_user_preferences_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        NEW.updated_at = NOW();
        INSERT INTO public.user_preferences_audit_log (user_id, old_values, new_values, action)
        VALUES (NEW.user_id, to_jsonb(OLD), to_jsonb(NEW), 'UPDATE');
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO public.user_preferences_audit_log (user_id, old_values, new_values, action)
        VALUES (NEW.user_id, NULL, to_jsonb(NEW), 'INSERT');
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

--
-- Name: has_access_to_psychologist_data(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_access_to_psychologist_data(target_psychologist_id uuid) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO ''
    AS $$
    SELECT (
        auth.uid() = target_psychologist_id
        OR
        EXISTS (
            SELECT 1 
            FROM public.psychologist_assistants 
            WHERE psychologist_id = target_psychologist_id 
            AND assistant_id = auth.uid()
        )
    );
$$;

--
-- Name: has_client_access(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.has_client_access(p_psychologist_client_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.psychologist_clients
    where id = p_psychologist_client_id
      and psychologist_id = (select auth.uid())
  );
$$;
