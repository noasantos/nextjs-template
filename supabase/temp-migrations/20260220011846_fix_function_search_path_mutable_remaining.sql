-- Migration: Fix remaining Function Search Path Mutable issues
-- Created at: 2026-02-20
-- Issue: Functions without explicit search_path parameter
-- Fix: Add SET search_path = '' to all affected functions
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable

-- Fix 1: calculate_cancellation_fee
CREATE OR REPLACE FUNCTION public.calculate_cancellation_fee(
  p_psychologist_id uuid, 
  p_session_start_time timestamp with time zone, 
  p_cancellation_time timestamp with time zone DEFAULT now()
)
RETURNS TABLE(fee_percentage integer, min_notice_hours integer, hours_before_session numeric, policy_applies boolean, fee_amount_cents integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;
-- Fix 2: check_file_size
CREATE OR REPLACE FUNCTION public.check_file_size()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  IF NEW.bucket_id = 'patient-documents'
     AND COALESCE((NEW.metadata->>'size')::bigint, 0) > 10485760 THEN
    RAISE EXCEPTION 'File too large. Maximum size is 10MB';
  END IF;
  RETURN NEW;
END;
$function$;
-- Fix 3: cleanup_old_audit_logs (void version)
CREATE OR REPLACE FUNCTION public.cleanup_old_audit_logs()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  DELETE FROM public.service_role_audit_log
  WHERE created_at < NOW() - INTERVAL '90 days';
END;
$function$;
-- Fix 4: clear_audit_context
CREATE OR REPLACE FUNCTION public.clear_audit_context()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  PERFORM set_config('app.current_user_id', '', true);
END;
$function$;
-- Fix 5: complete_psychologist_onboarding
CREATE OR REPLACE FUNCTION public.complete_psychologist_onboarding()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;
-- Fix 6: compute_short_display_name
CREATE OR REPLACE FUNCTION public.compute_short_display_name(base_name text, surname text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $function$
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

  base_parts := regexp_split_to_array(normalized_base, '\\\\s+');
  IF COALESCE(array_length(base_parts, 1), 0) >= 2 THEN
    RETURN normalized_base;
  END IF;

  IF normalized_surname IS NULL THEN
    RETURN normalized_base;
  END IF;

  surname_parts := regexp_split_to_array(normalized_surname, '\\\\s+');
  surname_last_word := surname_parts[COALESCE(array_length(surname_parts, 1), 1)];

  IF surname_last_word IS NULL OR btrim(surname_last_word) = '' THEN
    RETURN normalized_base;
  END IF;

  RETURN normalized_base || ' ' || surname_last_word;
END;
$function$;
-- Fix 7: consolidate_daily_charges
CREATE OR REPLACE FUNCTION public.consolidate_daily_charges(p_psychologist_id uuid, p_date date)
RETURNS TABLE(action text, entry_id uuid, entry_date date, amount_cents integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
  FROM financial_categories
  WHERE psychologist_id = p_psychologist_id
    AND category_name = 'Consolidação Diária'
  LIMIT 1;
  
  IF v_category_id IS NULL THEN
    INSERT INTO financial_categories (
      psychologist_id, category_name, category_type, description, color, is_default, is_active, created_at, updated_at
    ) VALUES (
      p_psychologist_id, 'Consolidação Diária', 'income', 'Consolidação automática de cobranças pagas por dia', '#10B981', true, true, NOW(), NOW()
    )
    RETURNING id INTO v_category_id;
  END IF;
  
  SELECT COUNT(*), COALESCE(SUM(c.price_cents), 0)
  INTO v_charge_count, v_total_cents
  FROM psychologist_client_charges c
  JOIN clinical_sessions s ON s.id = c.session_id
  WHERE c.psychologist_id = p_psychologist_id
    AND c.payment_status = 'paid'
    AND s.start_time >= v_day_start
    AND s.start_time < v_day_end;
  
  SELECT id INTO v_existing_entry_id
  FROM psychologist_financial_entries
  WHERE psychologist_id = p_psychologist_id
    AND type = 'income'
    AND (category_id = v_category_id OR category_id IS NULL)
    AND description LIKE 'Serviços Prestados%'
    AND date_time::date = p_date
  LIMIT 1;
  
  IF v_charge_count = 0 THEN
    IF v_existing_entry_id IS NOT NULL THEN
      DELETE FROM psychologist_financial_entries WHERE id = v_existing_entry_id;
      RETURN QUERY SELECT 'deleted'::TEXT, v_existing_entry_id, p_date, 0;
    END IF;
  ELSIF v_existing_entry_id IS NOT NULL THEN
    UPDATE psychologist_financial_entries
    SET amount = v_total_cents, category_id = v_category_id,
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
    INSERT INTO psychologist_financial_entries (
      psychologist_id, type, category_id, amount, description, date_time, created_at, updated_at
    ) VALUES (
      p_psychologist_id, 'income', v_category_id, v_total_cents,
      'Serviços Prestados ' || to_char(p_date, 'DD') || ' ' ||
        CASE extract(month FROM p_date)
          WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
          WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
          WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
          WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
        END,
      p_date::TIMESTAMPTZ, NOW(), NOW()
    )
    RETURNING id INTO v_entry_id;
    RETURN QUERY SELECT 'created'::TEXT, v_entry_id, p_date, v_total_cents;
  END IF;
END;
$function$;
-- Fix 8: detect_high_volume_service_role_usage
CREATE OR REPLACE FUNCTION public.detect_high_volume_service_role_usage(threshold integer, window_minutes integer)
RETURNS TABLE(source text, operation_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT sra.source, COUNT(*) as operation_count
  FROM public.service_role_audit_log sra
  WHERE sra.created_at > NOW() - (window_minutes || ' minutes')::INTERVAL
  GROUP BY sra.source
  HAVING COUNT(*) > threshold;
END;
$function$;
-- Fix 9: detect_suspicious_error_patterns
CREATE OR REPLACE FUNCTION public.detect_suspicious_error_patterns()
RETURNS TABLE(source text, error_message text, error_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT sra.source, sra.error_message, COUNT(*) as error_count
  FROM public.service_role_audit_log sra
  WHERE sra.success = false AND sra.created_at > NOW() - INTERVAL '1 hour'
  GROUP BY sra.source, sra.error_message
  HAVING COUNT(*) > 10;
END;
$function$;
-- Fix 10: detect_unusual_table_access
CREATE OR REPLACE FUNCTION public.detect_unusual_table_access(whitelisted_tables text[])
RETURNS TABLE(source text, table_name text, access_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT sra.source, sra.table_name, COUNT(*) as access_count
  FROM public.service_role_audit_log sra
  WHERE sra.table_name IS NOT NULL
    AND NOT (sra.table_name = ANY(whitelisted_tables))
    AND sra.created_at > NOW() - INTERVAL '24 hours'
  GROUP BY sra.source, sra.table_name;
END;
$function$;
-- Fix 11: ensure_psychologist_for_current_user
CREATE OR REPLACE FUNCTION public.ensure_psychologist_for_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  insert into public.user_psychologists (id)
  values (v_user_id)
  on conflict (id) do nothing;
end;
$function$;
-- Fix 12: generate_patient_display_name
CREATE OR REPLACE FUNCTION public.generate_patient_display_name()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
DECLARE
  source_name TEXT;
BEGIN
  source_name := COALESCE(NULLIF(btrim(NEW.manual_preferred_name), ''), NEW.manual_first_name);
  NEW.manual_display_name := public.compute_short_display_name(source_name, NEW.manual_last_name);
  RETURN NEW;
END;
$function$;
-- Fix 13: generate_public_patient_display_name
CREATE OR REPLACE FUNCTION public.generate_public_patient_display_name()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
DECLARE
  source_name TEXT;
BEGIN
  source_name := COALESCE(NULLIF(btrim(NEW.preferred_name), ''), NEW.first_name);
  NEW.display_name := public.compute_short_display_name(source_name, NEW.last_name);
  RETURN NEW;
END;
$function$;
-- Fix 14: get_effective_cancellation_policy
CREATE OR REPLACE FUNCTION public.get_effective_cancellation_policy(
  p_psychologist_id uuid, 
  p_reference_timestamp timestamp with time zone DEFAULT now()
)
RETURNS TABLE(policy_code text, fee_percentage integer, min_notice_hours integer, effective_from timestamp with time zone, effective_until timestamp with time zone)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    pscp.policy_code::TEXT,
    (rv.metadata->>'fee_percentage')::INTEGER as fee_percentage,
    (rv.metadata->>'min_notice_hours')::INTEGER as min_notice_hours,
    pscp.effective_from,
    pscp.effective_until
  FROM public.psychologist_session_cancellation_policy pscp
  JOIN public.reference_values rv 
    ON rv.value = pscp.policy_code::TEXT 
    AND rv.category = 'cancellation_policy'
  WHERE pscp.psychologist_id = p_psychologist_id
    AND p_reference_timestamp >= pscp.effective_from
    AND (pscp.effective_until IS NULL OR p_reference_timestamp < pscp.effective_until)
  ORDER BY pscp.effective_from DESC
  LIMIT 1;
END;
$function$;
-- Fix 15: get_public_psychologist_by_username
CREATE OR REPLACE FUNCTION public.get_public_psychologist_by_username(p_username text)
RETURNS TABLE(id uuid, full_name text, avatar_url text, crp text, crp_state text, bio text, specialties jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RETURN QUERY
  SELECT p.id, p.full_name, p.avatar_url, p.crp, p.crp_state, pp.bio, pp.specialties::jsonb
  FROM user_psychologists p
  LEFT JOIN psychologist_profiles pp ON p.id = pp.id
  WHERE p.username = p_username;
END;
$function$;
-- Fix 16: get_sessions_needing_reminders
CREATE OR REPLACE FUNCTION public.get_sessions_needing_reminders(p_reminder_type text, p_batch_size integer DEFAULT 100)
RETURNS TABLE(session_id uuid, psychologist_id uuid, patient_id uuid, session_start_time timestamp with time zone, patient_phone text, patient_email text, reminder_hours_before integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;
-- Fix 17: handle_new_psychologist
CREATE OR REPLACE FUNCTION public.handle_new_psychologist()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NEW.role = 'psychologist' THEN
    INSERT INTO public.user_psychologists (id)
    VALUES (NEW.user_id)
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;
-- Fix 18: handle_stripe_subscription_update
CREATE OR REPLACE FUNCTION public.handle_stripe_subscription_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;
-- Fix 19: mark_reminder_sent
CREATE OR REPLACE FUNCTION public.mark_reminder_sent(p_session_id uuid, p_reminder_type text, p_channel text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;
-- Fix 20: migrate_weekly_to_daily_consolidation
CREATE OR REPLACE FUNCTION public.migrate_weekly_to_daily_consolidation()
RETURNS TABLE(entries_migrated integer, entries_deleted integer, new_daily_entries_created integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_entries_migrated INTEGER := 0;
  v_entries_deleted INTEGER := 0;
  v_new_entries_created INTEGER := 0;
  v_daily_category_id UUID;
  week_entry RECORD;
  session_date DATE;
  daily_total INTEGER;
  existing_daily_id UUID;
  new_entry_id UUID;
BEGIN
  SELECT id INTO v_daily_category_id
  FROM financial_transaction_categories
  WHERE name = 'Consolidação Diária' AND type = 'INCOME';
  
  IF v_daily_category_id IS NULL THEN
    RAISE EXCEPTION 'Categoria Consolidação Diária não encontrada';
  END IF;

  FOR week_entry IN
    SELECT fe.id as entry_id, fe.psychologist_id, fe.amount, fe.date_time, fe.description, fe.created_by
    FROM psychologist_financial_entries fe
    WHERE fe.type = 'income' AND fe.description LIKE 'Serviços Prestados%'
      AND fe.transaction_category_id = v_daily_category_id
  LOOP
    FOR session_date IN
      SELECT DISTINCT DATE(cs.start_time) as session_date
      FROM psychologist_client_charges ch
      JOIN clinical_sessions cs ON cs.id = ch.session_id
      WHERE ch.psychologist_id = week_entry.psychologist_id AND ch.payment_status = 'paid'
        AND cs.start_time >= week_entry.date_time AND cs.start_time < week_entry.date_time + INTERVAL '7 days'
    LOOP
      SELECT COALESCE(SUM(ch.price_cents), 0) INTO daily_total
      FROM psychologist_client_charges ch
      JOIN clinical_sessions cs ON cs.id = ch.session_id
      WHERE ch.psychologist_id = week_entry.psychologist_id AND ch.payment_status = 'paid'
        AND DATE(cs.start_time) = session_date;
      
      SELECT id INTO existing_daily_id
      FROM psychologist_financial_entries
      WHERE psychologist_id = week_entry.psychologist_id AND type = 'income'
        AND description LIKE 'Serviços Prestados%' AND DATE(date_time) = session_date
      LIMIT 1;
      
      IF existing_daily_id IS NOT NULL THEN
        UPDATE psychologist_financial_entries
        SET amount = daily_total,
          description = 'Serviços Prestados ' || TO_CHAR(session_date, 'DD') || ' ' ||
            CASE EXTRACT(MONTH FROM session_date)
              WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar' WHEN 4 THEN 'Abr'
              WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun' WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago'
              WHEN 9 THEN 'Set' WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
            END,
          date_time = session_date::TIMESTAMPTZ, updated_at = NOW()
        WHERE id = existing_daily_id;
        v_entries_migrated := v_entries_migrated + 1;
      ELSE
        INSERT INTO psychologist_financial_entries (
          psychologist_id, type, amount, description, date_time, transaction_category_id, status, created_by, created_at, updated_at
        )
        SELECT week_entry.psychologist_id, 'income', daily_total, 'Serviços Prestados ' || TO_CHAR(session_date, 'DD') || ' ' ||
            CASE EXTRACT(MONTH FROM session_date)
              WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar' WHEN 4 THEN 'Abr'
              WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun' WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago'
              WHEN 9 THEN 'Set' WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
            END,
          session_date::TIMESTAMPTZ, v_daily_category_id, 'confirmed', week_entry.psychologist_id, NOW(), NOW()
        RETURNING id INTO new_entry_id;
        v_new_entries_created := v_new_entries_created + 1;
      END IF;
    END LOOP;
    
    DELETE FROM psychologist_financial_entries WHERE id = week_entry.entry_id;
    v_entries_deleted := v_entries_deleted + 1;
  END LOOP;
  
  RETURN QUERY SELECT v_entries_migrated, v_entries_deleted, v_new_entries_created;
END;
$function$;
-- Fix 21: process_pending_session_billing (table version)
CREATE OR REPLACE FUNCTION public.process_pending_session_billing(p_batch_size integer DEFAULT 100)
RETURNS TABLE(processed_count integer, success_count integer, error_count integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_processed INTEGER := 0;
  v_success INTEGER := 0;
  v_errors INTEGER := 0;
  v_session RECORD;
BEGIN
  FOR v_session IN
    SELECT pcs.id as session_id, pcs.psychologist_id, pcs.billing_status, pcs.billing_next_attempt_at,
      pcs.charge_id, pc.price_cents, pc.description, pcs.automation_metadata
    FROM public.psychologist_clinical_sessions pcs
    LEFT JOIN public.psychologist_patient_charges pc ON pc.id = pcs.charge_id
    WHERE pcs.billing_status IN ('pending', 'failed')
      AND (pcs.billing_next_attempt_at IS NULL OR pcs.billing_next_attempt_at <= NOW())
      AND pcs.billing_attempt_count < 3
    ORDER BY pcs.billing_next_attempt_at ASC
    LIMIT p_batch_size
  LOOP
    v_processed := v_processed + 1;
    BEGIN
      UPDATE public.psychologist_clinical_sessions
      SET billing_attempt_count = COALESCE(billing_attempt_count, 0) + 1,
        billing_next_attempt_at = CASE 
          WHEN billing_attempt_count >= 2 THEN NULL
          ELSE NOW() + (INTERVAL '1 hour' * POWER(2, COALESCE(billing_attempt_count, 0)))
        END,
        automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
          'last_billing_attempt', NOW(),
          'billing_attempt_' || COALESCE(billing_attempt_count, 0) + 1, jsonb_build_object('status', 'processing', 'timestamp', NOW())
        )
      WHERE id = v_session.session_id;
      v_success := v_success + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      UPDATE public.psychologist_clinical_sessions
      SET billing_last_error = SQLERRM,
        automation_metadata = COALESCE(automation_metadata, '{}'::jsonb) || jsonb_build_object(
          'last_billing_error', jsonb_build_object('message', SQLERRM, 'timestamp', NOW())
        )
      WHERE id = v_session.session_id;
    END;
  END LOOP;
  
  RETURN QUERY SELECT v_processed, v_success, v_errors;
END;
$function$;
-- Fix 22: provision_user_role
CREATE OR REPLACE FUNCTION public.provision_user_role(p_user_id uuid, p_role app_role)
RETURNS app_role
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
declare
  v_existing_role public.app_role;
begin
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
  
  select role into v_existing_role from public.user_roles where user_id = p_user_id;
  if v_existing_role is not null then
    return v_existing_role;
  end if;
  
  insert into public.user_roles (user_id, role) values (p_user_id, p_role);
  
  case p_role
    when 'psychologist' then
      insert into public.user_psychologists (id, subscription_status, onboarding_completed)
      values (p_user_id, 'inactive', false) on conflict (id) do nothing;
    when 'patient' then
      insert into public.user_patients (id) values (p_user_id) on conflict (id) do nothing;
    when 'assistant' then
      insert into public.user_assistants (id) values (p_user_id) on conflict (id) do nothing;
    when 'admin' then
      insert into public.user_admins (id) values (p_user_id) on conflict (id) do nothing;
  end case;
  
  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('user_role', p_role)
  where id = p_user_id;
  
  return p_role;
end;
$function$;
-- Fix 23: recalculate_daily_consolidation_for_charge
CREATE OR REPLACE FUNCTION public.recalculate_daily_consolidation_for_charge(p_charge_id uuid)
RETURNS TABLE(action text, entry_id uuid, entry_date date, amount_cents integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_psychologist_id UUID;
  v_session_date DATE;
BEGIN
  SELECT c.psychologist_id, s.start_time::date
  INTO v_psychologist_id, v_session_date
  FROM psychologist_client_charges c
  JOIN clinical_sessions s ON s.id = c.session_id
  WHERE c.id = p_charge_id;
  
  IF v_psychologist_id IS NULL THEN
    RETURN;
  END IF;
  
  RETURN QUERY SELECT * FROM consolidate_daily_charges(v_psychologist_id, v_session_date);
END;
$function$;
-- Fix 24: set_audit_context
CREATE OR REPLACE FUNCTION public.set_audit_context(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  PERFORM set_config('app.current_user_id', p_user_id::text, true);
END;
$function$;
-- Fix 25: set_psychologist_cancellation_policy
CREATE OR REPLACE FUNCTION public.set_psychologist_cancellation_policy(p_psychologist_id uuid, p_policy_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_valid_policy BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.reference_values 
    WHERE category = 'cancellation_policy' AND value = p_policy_code AND is_active = true
  ) INTO v_valid_policy;
  
  IF NOT v_valid_policy THEN
    RAISE EXCEPTION 'Invalid cancellation policy code: %', p_policy_code;
  END IF;
  
  INSERT INTO public.psychologist_session_cancellation_policy (psychologist_id, policy_code, effective_from)
  VALUES (p_psychologist_id, p_policy_code::public.cancellation_policy_code, NOW());
  
  RETURN TRUE;
END;
$function$;
-- Fix 26: sync_calendar_event_to_session
CREATE OR REPLACE FUNCTION public.sync_calendar_event_to_session(p_event_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_event RECORD;
  v_session_id UUID;
BEGIN
  SELECT ce.id, ce.start_datetime, ce.end_datetime, ce.psychologist_id, pcs.id as existing_session_id
  INTO v_event
  FROM public.calendar_events ce
  LEFT JOIN public.psychologist_clinical_sessions pcs ON pcs.calendar_event_id = ce.id
  WHERE ce.id = p_event_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  IF v_event.existing_session_id IS NOT NULL THEN
    UPDATE public.psychologist_clinical_sessions
    SET start_time = v_event.start_datetime, end_time = v_event.end_datetime, updated_at = NOW()
    WHERE id = v_event.existing_session_id;
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$function$;
-- Fix 27: sync_marketplace_profile
CREATE OR REPLACE FUNCTION public.sync_marketplace_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_crp text;
  v_crp_state text;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM public.marketplace_psychologist_profiles WHERE psychologist_id = OLD.id;
    DELETE FROM public.marketplace_linktree_links WHERE psychologist_id = OLD.id;
    DELETE FROM public.marketplace_locations WHERE psychologist_id = OLD.id;
    RETURN OLD;
  END IF;

  IF NOT public.is_profile_public(NEW.id) THEN
    DELETE FROM public.marketplace_psychologist_profiles WHERE psychologist_id = NEW.id;
    DELETE FROM public.marketplace_linktree_links WHERE psychologist_id = NEW.id;
    DELETE FROM public.marketplace_locations WHERE psychologist_id = NEW.id;
    RETURN NEW;
  END IF;

  SELECT crp, crp_state INTO v_crp, v_crp_state
  FROM public.user_psychologists WHERE id = NEW.id;

  INSERT INTO public.marketplace_psychologist_profiles (
    psychologist_id, display_name, full_name, username, professional_title, crp, crp_state, bio, specialties,
    therapeutic_approaches, session_duration, session_price, city, state, languages, avatar_url, avatar_path,
    background_url, background_path, slug, social_links, linktree_theme, tagline, profile_sections, video_section,
    academic_timeline, gallery_photos, is_public, show_in_marketplace, created_at, updated_at
  ) VALUES (
    NEW.id, NEW.display_name, NEW.full_name, NEW.slug, NEW.tagline, v_crp, v_crp_state, NEW.bio, NEW.specialties,
    NEW.therapeutic_approaches, NEW.session_duration, NEW.session_price, NEW.city, NEW.state, NEW.languages,
    NEW.avatar_url, NEW.avatar_path, NEW.background_url, NEW.background_path, NEW.slug, NEW.social_links,
    NEW.linktree_theme, NEW.tagline, NEW.profile_sections, NEW.video_section, NEW.academic_timeline,
    NEW.gallery_photos, NEW.is_public, NEW.show_in_marketplace, NEW.created_at, NEW.updated_at
  ) ON CONFLICT (psychologist_id) DO UPDATE SET
    display_name = EXCLUDED.display_name, full_name = EXCLUDED.full_name, username = EXCLUDED.username,
    professional_title = EXCLUDED.professional_title, crp = EXCLUDED.crp, crp_state = EXCLUDED.crp_state,
    bio = EXCLUDED.bio, specialties = EXCLUDED.specialties, therapeutic_approaches = EXCLUDED.therapeutic_approaches,
    session_duration = EXCLUDED.session_duration, session_price = EXCLUDED.session_price, city = EXCLUDED.city,
    state = EXCLUDED.state, languages = EXCLUDED.languages, avatar_url = EXCLUDED.avatar_url,
    avatar_path = EXCLUDED.avatar_path, background_url = EXCLUDED.background_url,
    background_path = EXCLUDED.background_path, slug = EXCLUDED.slug, social_links = EXCLUDED.social_links,
    linktree_theme = EXCLUDED.linktree_theme, tagline = EXCLUDED.tagline, profile_sections = EXCLUDED.profile_sections,
    video_section = EXCLUDED.video_section, academic_timeline = EXCLUDED.academic_timeline,
    gallery_photos = EXCLUDED.gallery_photos, is_public = EXCLUDED.is_public,
    show_in_marketplace = EXCLUDED.show_in_marketplace, updated_at = EXCLUDED.updated_at;

  RETURN NEW;
END;
$function$;
-- Fix 28: tr_close_previous_cancellation_policy
CREATE OR REPLACE FUNCTION public.tr_close_previous_cancellation_policy()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  UPDATE public.psychologist_session_cancellation_policy
  SET effective_until = NOW()
  WHERE psychologist_id = NEW.psychologist_id
    AND effective_until IS NULL AND id IS DISTINCT FROM NEW.id;
  
  RETURN NEW;
END;
$function$;
-- Fix 29: tr_sync_calendar_to_session
CREATE OR REPLACE FUNCTION public.tr_sync_calendar_to_session()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;
-- Fix 30: update_attendance_confirmation
CREATE OR REPLACE FUNCTION public.update_attendance_confirmation(
  p_session_id uuid, 
  p_confirmed boolean, 
  p_confirmation_source text, 
  p_confirmed_by uuid DEFAULT NULL::uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;
