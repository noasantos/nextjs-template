-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:05Z

SET check_function_bodies = false;

--
-- Name: FUNCTION clear_audit_context(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.clear_audit_context() IS 'Clears the audit context user ID. Useful for long-running transactions or explicit cleanup.';

--
-- Name: complete_onboarding_step(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_onboarding_step(p_psychologist_id uuid, p_step text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_all_complete BOOLEAN;
BEGIN
  -- Update specific step
  UPDATE public.psychologist_onboarding_state
  SET 
    payment_step_completed = CASE WHEN p_step = 'payment' THEN TRUE ELSE payment_step_completed END,
    identity_step_completed = CASE WHEN p_step = 'identity' THEN TRUE ELSE identity_step_completed END,
    professional_step_completed = CASE WHEN p_step = 'professional' THEN TRUE ELSE professional_step_completed END,
    configuration_step_completed = CASE WHEN p_step = 'configuration' THEN TRUE ELSE configuration_step_completed END,
    profile_step_completed = CASE WHEN p_step = 'profile' THEN TRUE ELSE profile_step_completed END,
    updated_at = NOW()
  WHERE psychologist_id = p_psychologist_id;
  
  -- Recalculate progress
  PERFORM public.calculate_onboarding_progress(p_psychologist_id);
  
  -- Check if all steps are complete
  SELECT (
    payment_step_completed 
    AND identity_step_completed 
    AND professional_step_completed 
    AND configuration_step_completed 
    AND profile_step_completed
  ) INTO v_all_complete
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = p_psychologist_id;
  
  -- If complete, mark timestamp
  IF v_all_complete THEN
    UPDATE public.psychologist_onboarding_state
    SET onboarding_completed_at = COALESCE(onboarding_completed_at, NOW()),
        updated_at = NOW()
    WHERE psychologist_id = p_psychologist_id;
    
    -- Also update flag in user_psychologists for compatibility
    UPDATE public.user_psychologists
    SET onboarding_completed = TRUE,
        updated_at = NOW()
    WHERE id = p_psychologist_id;
  END IF;
  
  RETURN TRUE;
END;
$$;

--
-- Name: FUNCTION complete_onboarding_step(p_psychologist_id uuid, p_step text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.complete_onboarding_step(p_psychologist_id uuid, p_step text) IS 'Marks a specific onboarding step as complete for a given psychologist.
Steps: identity → professional → payment → configuration → profile';

--
-- Name: complete_psychologist_onboarding(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.complete_psychologist_onboarding() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
declare
  p_user_id uuid;
  p_role public.app_role;
begin
  p_user_id := auth.uid();
  
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  if p_role != 'psychologist' then
    raise exception 'Only psychologists can complete onboarding';
  end if;
  
  update public.user_psychologists
  set 
    onboarding_completed = true,
    updated_at = now()
  where id = p_user_id;
  
  return true;
end;
$$;

--
-- Name: FUNCTION complete_psychologist_onboarding(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.complete_psychologist_onboarding() IS 'Marks psychologist onboarding as completed';

--
-- Name: compute_short_display_name(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compute_short_display_name(base_name text, surname text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO ''
    AS $$
DECLARE
  normalized_base TEXT;
  normalized_surname TEXT;
  base_parts TEXT[];
  surname_parts TEXT[];
  surname_last_word TEXT;
BEGIN
  normalized_base := NULLIF(btrim(base_name), '');
  normalized_surname := NULLIF(btrim(surname), '');

  IF normalized_base IS NULL THEN
    RETURN NULL;
  END IF;

  base_parts := regexp_split_to_array(normalized_base, '\\s+');
  IF COALESCE(array_length(base_parts, 1), 0) >= 2 THEN
    RETURN normalized_base;
  END IF;

  IF normalized_surname IS NULL THEN
    RETURN normalized_base;
  END IF;

  surname_parts := regexp_split_to_array(normalized_surname, '\\s+');
  surname_last_word := surname_parts[COALESCE(array_length(surname_parts, 1), 1)];

  IF surname_last_word IS NULL OR btrim(surname_last_word) = '' THEN
    RETURN normalized_base;
  END IF;

  RETURN normalized_base || ' ' || surname_last_word;
END;
$$;

--
-- Name: consolidate_daily_charges(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.consolidate_daily_charges(p_psychologist_id uuid, p_date date) RETURNS TABLE(action text, entry_id uuid, entry_date date, amount_cents integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $fn$
        DECLARE
          v_day_start TIMESTAMPTZ;
          v_day_end TIMESTAMPTZ;
          v_total_cents INTEGER;
          v_entry_id UUID;
          v_category_id UUID;
          v_existing_entry_id UUID;
          v_charge_count INTEGER;
        BEGIN
          v_day_start := p_date::TIMESTAMPTZ;
          v_day_end := (p_date + INTERVAL '1 day')::TIMESTAMPTZ;
          
          SELECT id INTO v_category_id
          FROM public.reference_values
          WHERE category = 'financial_transaction_category'
            AND value = 'daily_consolidation'
          LIMIT 1;
          
          -- Fallback for legacy environments
          IF v_category_id IS NULL THEN
            IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'financial_categories' AND schemaname = 'public') THEN
                EXECUTE 'SELECT id FROM public.financial_categories WHERE psychologist_id = $1 AND category_name = $2 LIMIT 1'
                INTO v_category_id
                USING p_psychologist_id, 'Consolidação Diária';
            END IF;
          END IF;
          
          SELECT COUNT(*), COALESCE(SUM(c.price_cents), 0)
          INTO v_charge_count, v_total_cents
          FROM public.psychologist_patient_charges c
          JOIN public.psychologist_clinical_sessions s ON s.id = c.session_id
          WHERE c.psychologist_id = p_psychologist_id
            AND c.payment_status = 'paid'
            AND s.start_time >= v_day_start
            AND s.start_time < v_day_end;
          
          SELECT id INTO v_existing_entry_id
          FROM public.psychologist_financial_entries
          WHERE psychologist_id = p_psychologist_id
            AND type = 'income'
            AND (transaction_category_id = v_category_id OR transaction_category_id IS NULL)
            AND description LIKE 'Serviços Prestados%'
            AND date_time::date = p_date
          LIMIT 1;
          
          IF v_charge_count = 0 THEN
            IF v_existing_entry_id IS NOT NULL THEN
              DELETE FROM public.psychologist_financial_entries WHERE id = v_existing_entry_id;
              RETURN QUERY SELECT 'deleted'::TEXT, v_existing_entry_id, p_date, 0;
            END IF;
          ELSIF v_existing_entry_id IS NOT NULL THEN
            UPDATE public.psychologist_financial_entries
            SET amount = v_total_cents, transaction_category_id = v_category_id,
              description = 'Serviços Prestados ' || to_char(p_date, 'DD') || ' ' ||
                CASE extract(month FROM p_date)
                  WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
                  WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
                  WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
                  WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
                END,
              updated_at = NOW()
            WHERE id = v_existing_entry_id;
            RETURN QUERY SELECT 'updated'::TEXT, v_existing_entry_id, p_date, v_total_cents;
          ELSE
            INSERT INTO public.psychologist_financial_entries (
              psychologist_id, type, transaction_category_id, amount, description, date_time, created_at, updated_at, status
            ) VALUES (
              p_psychologist_id, 'income', v_category_id, v_total_cents,
              'Serviços Prestados ' || to_char(p_date, 'DD') || ' ' ||
                CASE extract(month FROM p_date)
                  WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
                  WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
                  WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
                  WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
                END,
              p_date::TIMESTAMPTZ, NOW(), NOW(), 'confirmed'
            )
            RETURNING id INTO v_entry_id;
            RETURN QUERY SELECT 'created'::TEXT, v_entry_id, p_date, v_total_cents;
          END IF;
        END;
        $fn$;
