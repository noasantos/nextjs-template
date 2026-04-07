-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:38Z

SET check_function_bodies = false;

--
-- Name: sync_clinical_session_to_busy_slots(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_clinical_session_to_busy_slots() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_end_time timestamptz;
  v_slot_range tstzrange;
  v_has_calendar_event boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.busy_slots
    WHERE source_type = 'clinical_session' AND source_id = OLD.id;
    RETURN OLD;
  END IF;

  v_end_time := NEW.start_time + (COALESCE(NEW.duration_minutes, 50) || ' minutes')::interval;
  v_slot_range := tstzrange(NEW.start_time, v_end_time, '[)');

  -- Check if a calendar_event already covers this exact slot
  SELECT EXISTS (
    SELECT 1 FROM public.busy_slots bs
    WHERE bs.psychologist_id = NEW.psychologist_id
      AND bs.slot_range && v_slot_range
      AND bs.source_type = 'calendar_event'
      AND bs.is_hard_block = true
  ) INTO v_has_calendar_event;

  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF COALESCE(NEW.status::text, 'scheduled') = 'cancelled' THEN
      DELETE FROM public.busy_slots
      WHERE source_type = 'clinical_session' AND source_id = NEW.id;
    ELSIF NOT v_has_calendar_event THEN
      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        NEW.psychologist_id,
        v_slot_range,
        'clinical_session',
        NEW.id,
        'session',
        true,
        COALESCE(NEW.snapshot_service_name, 'Sessão')
      )
      ON CONFLICT (source_type, source_id) DO UPDATE SET
        psychologist_id = EXCLUDED.psychologist_id,
        slot_range = EXCLUDED.slot_range,
        is_hard_block = EXCLUDED.is_hard_block,
        title = EXCLUDED.title;
    ELSE
      -- If there is a calendar event, make sure we don't have a stray session slot
      DELETE FROM public.busy_slots
      WHERE source_type = 'clinical_session' AND source_id = NEW.id;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;

--
-- Name: sync_marketplace_linktree_link(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_marketplace_linktree_link() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  -- No-op: Tables marketplace_* were removed and unified into public_*
  -- Data is now maintained directly in public_linktree_links, no sync needed
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

--
-- Name: sync_marketplace_location(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_marketplace_location() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  -- No-op: Tables marketplace_* were removed and unified into public_*
  -- Data is now maintained directly in public_locations, no sync needed
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

--
-- Name: sync_marketplace_profile(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_marketplace_profile() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  -- No-op: Tables marketplace_* were removed and unified into public_*
  -- Data is now maintained directly in public_profiles, no sync needed
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

--
-- Name: FUNCTION sync_marketplace_profile(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sync_marketplace_profile() IS 'Syncs public profile data to marketplace tables when profile changes';

--
-- Name: sync_onboarding_completed_with_essential(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_onboarding_completed_with_essential() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_essential_complete BOOLEAN;
BEGIN
  -- Verificar se Fase 1 está completa usando a view atualizada
  SELECT essential_complete INTO v_essential_complete
  FROM public.psychologist_onboarding_summary
  WHERE psychologist_id = NEW.id;
  
  -- Sincronizar onboarding_completed com essential_complete
  IF v_essential_complete AND NOT COALESCE(NEW.onboarding_completed, FALSE) THEN
    NEW.onboarding_completed := TRUE;
    NEW.updated_at := NOW();
  END IF;
  
  RETURN NEW;
END;
$$;

--
-- Name: FUNCTION sync_onboarding_completed_with_essential(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sync_onboarding_completed_with_essential() IS 'Trigger function: sincroniza onboarding_completed com essential_complete (Fase 1).
Marca onboarding_completed = TRUE quando identity + professional + payment estão completos.';

--
-- Name: sync_payment_step_with_subscription(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_payment_step_with_subscription() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  -- Quando subscription muda para active/trialing, marcar payment_step
  IF NEW.subscription_status IN ('active', 'trialing') THEN
    INSERT INTO public.psychologist_onboarding_state (psychologist_id, payment_step_completed)
    VALUES (NEW.id, TRUE)
    ON CONFLICT (psychologist_id) 
    DO UPDATE SET 
      payment_step_completed = TRUE,
      updated_at = NOW();
    
    -- Recalcular progresso
    PERFORM public.calculate_onboarding_progress(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;

--
-- Name: FUNCTION sync_payment_step_with_subscription(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.sync_payment_step_with_subscription() IS 'Trigger que sincroniza o passo de pagamento quando a subscription fica ativa.';

--
-- Name: sync_user_app_metadata(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_user_app_metadata(p_onboarding_completed boolean DEFAULT NULL::boolean) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  update auth.users
  set raw_app_meta_data = case
    when p_onboarding_completed is null then coalesce(raw_app_meta_data, '{}'::jsonb)
    else jsonb_set(
      coalesce(raw_app_meta_data, '{}'::jsonb),
      '{onboarding_completed}',
      to_jsonb(p_onboarding_completed),
      true
    )
  end
  where id = v_user_id;
end;
$$;

--
-- Name: sync_username_to_profile(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_username_to_profile() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    UPDATE public.psychologist_profiles
    SET
      slug = NEW.username,
      updated_at = NOW()
    WHERE id = NEW.id
      AND slug IS DISTINCT FROM NEW.username;
  END IF;

  RETURN NEW;
END;
$$;

--
-- Name: sync_username_to_psychologist(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_username_to_psychologist() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NEW.slug IS DISTINCT FROM OLD.slug THEN
    UPDATE public.psychologists
    SET
      username = NEW.slug,
      updated_at = NOW()
    WHERE id = NEW.id
      AND username IS DISTINCT FROM NEW.slug;
  END IF;

  RETURN NEW;
END;
$$;

--
-- Name: text_to_lexical_base64(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.text_to_lexical_base64(input_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select encode(
    format(
      '{"root":{"children":[{"children":[{"detail":0,"format":0,"mode":"normal","style":"","text":"%s","type":"text","version":1}],"direction":"ltr","format":"","indent":0,"type":"paragraph","version":1}],"direction":"ltr","format":"","indent":0,"type":"root","version":1}}',
      replace(replace(replace(input_text, '\', '\\'), '"', '\"'), E'\n', '\n')
    )::bytea,
    'base64'
  );
$$;

--
-- Name: tr_close_previous_cancellation_policy(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tr_close_previous_cancellation_policy() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  UPDATE public.psychologist_session_cancellation_policy
  SET effective_until = NOW()
  WHERE psychologist_id = NEW.psychologist_id
    AND effective_until IS NULL AND id IS DISTINCT FROM NEW.id;
  
  RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_close_previous_cancellation_policy(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.tr_close_previous_cancellation_policy() IS 'Automatically deactivates the previous cancellation policy when a new one is inserted';

--
-- Name: tr_sync_calendar_to_session(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tr_sync_calendar_to_session() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
  IF NEW.event_type = 'session' AND (
    OLD.start_datetime IS DISTINCT FROM NEW.start_datetime
    OR OLD.end_datetime IS DISTINCT FROM NEW.end_datetime
  ) THEN
    UPDATE public.psychologist_clinical_sessions
    SET start_time = NEW.start_datetime, end_time = NEW.end_datetime, updated_at = NOW()
    WHERE calendar_event_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

--
-- Name: FUNCTION tr_sync_calendar_to_session(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.tr_sync_calendar_to_session() IS 'Automatically syncs calendar event changes to clinical sessions';
