-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:30Z

SET check_function_bodies = false;

--
-- Name: migrate_weekly_to_daily_consolidation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.migrate_weekly_to_daily_consolidation() RETURNS TABLE(entries_migrated integer, entries_deleted integer, new_daily_entries_created integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $fn$
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
          FROM public.reference_values
          WHERE category = 'financial_transaction_category' AND value = 'daily_consolidation';
          
          IF v_daily_category_id IS NULL THEN
            IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'financial_transaction_categories' AND schemaname = 'public') THEN
                EXECUTE 'SELECT id FROM public.financial_transaction_categories WHERE name = $1 AND type = $2'
                INTO v_daily_category_id
                USING 'Consolidação Diária', 'INCOME';
            END IF;
          END IF;

          IF v_daily_category_id IS NULL THEN
            RAISE EXCEPTION 'Categoria Consolidação Diária não encontrada';
          END IF;

          FOR week_entry IN
            SELECT fe.id as entry_id, fe.psychologist_id, fe.amount, fe.date_time, fe.description, fe.created_by
            FROM public.psychologist_financial_entries fe
            WHERE fe.type = 'income' AND fe.description LIKE 'Serviços Prestados%'
              AND fe.transaction_category_id = v_daily_category_id
          LOOP
            FOR session_date IN
              SELECT DISTINCT DATE(cs.start_time) as session_date
              FROM public.psychologist_patient_charges ch
              JOIN public.psychologist_clinical_sessions cs ON cs.id = ch.session_id
              WHERE ch.psychologist_id = week_entry.psychologist_id AND ch.payment_status = 'paid'
                AND cs.start_time >= week_entry.date_time AND cs.start_time < week_entry.date_time + INTERVAL '7 days'
            LOOP
              SELECT COALESCE(SUM(ch.price_cents), 0) INTO daily_total
              FROM public.psychologist_patient_charges ch
              JOIN public.psychologist_clinical_sessions cs ON cs.id = ch.session_id
              WHERE ch.psychologist_id = week_entry.psychologist_id AND ch.payment_status = 'paid'
                AND DATE(cs.start_time) = session_date;
              
              SELECT id INTO existing_daily_id
              FROM public.psychologist_financial_entries
              WHERE psychologist_id = week_entry.psychologist_id AND type = 'income'
                AND description LIKE 'Serviços Prestados%' AND DATE(date_time) = session_date
              LIMIT 1;
              
              IF existing_daily_id IS NOT NULL THEN
                UPDATE public.psychologist_financial_entries
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
                INSERT INTO public.psychologist_financial_entries (
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
            
            DELETE FROM public.psychologist_financial_entries WHERE id = week_entry.entry_id;
            v_entries_deleted := v_entries_deleted + 1;
          END LOOP;
          
          RETURN QUERY SELECT v_entries_migrated, v_entries_deleted, v_new_entries_created;
        END;
        $fn$;

--
-- Name: pgmq_archive_message(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pgmq_archive_message(p_queue_name text, p_msg_id bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $fn$
DECLARE
  v_result boolean := false;
BEGIN
  EXECUTE 'SELECT COALESCE(pgmq.archive($1, $2), false)'
    INTO v_result
    USING p_queue_name, p_msg_id;

  RETURN v_result;
END;
$fn$;

--
-- Name: pgmq_delete_message(text, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pgmq_delete_message(p_queue_name text, p_msg_id bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $fn$
DECLARE
  v_result boolean := false;
BEGIN
  EXECUTE 'SELECT COALESCE(pgmq.delete($1, $2), false)'
    INTO v_result
    USING p_queue_name, p_msg_id;

  RETURN v_result;
END;
$fn$;

--
-- Name: pgmq_queue_backlog(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pgmq_queue_backlog(p_queue_name text) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pgmq'
    AS $$
DECLARE
  v_count bigint := 0;
BEGIN
  BEGIN
    EXECUTE format('SELECT COUNT(*)::bigint FROM pgmq.%I', 'q_' || p_queue_name)
      INTO v_count;
  EXCEPTION
    WHEN undefined_table THEN
      v_count := 0;
  END;

  RETURN COALESCE(v_count, 0);
END;
$$;

--
-- Name: pgmq_read_messages(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pgmq_read_messages(p_queue_name text, p_vt integer, p_qty integer) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $fn$
DECLARE
  v_result jsonb;
BEGIN
  EXECUTE $q$
    SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
    FROM pgmq.read($1, $2, $3) AS t
  $q$
    INTO v_result
    USING p_queue_name, p_vt, p_qty;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$fn$;

--
-- Name: process_audit_log(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.process_audit_log() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
  v_user_id        UUID;
  v_user_type      TEXT;
  v_record_id      TEXT;
  v_changed_fields JSONB;
  v_old_data       JSONB;
  v_new_data       JSONB;
  v_correlation_id UUID;
  v_session_user_id TEXT;
BEGIN
  -- Get user ID from JWT (normal auth) OR from session variable (service role)
  -- Priority: auth.uid() for user-initiated actions, app.current_user_id for service role
  v_session_user_id := NULLIF(current_setting('app.current_user_id', true), '');
  v_user_id := COALESCE(auth.uid(), v_session_user_id::uuid);
  
  -- Determine user type and validate context
  IF auth.uid() IS NOT NULL THEN
    -- Normal authenticated context: look up the user's role
    SELECT role::text INTO v_user_type
    FROM public.user_roles
    WHERE user_id = v_user_id
    LIMIT 1;

    IF v_user_type IS NULL THEN
      v_user_type := 'authenticated';
    END IF;
  ELSIF v_session_user_id IS NOT NULL THEN
    -- Service-role context with explicit user context set
    v_user_type := 'service_role';
    
    -- Verify the session user_id matches the row being modified (for user_roles table)
    -- This provides an additional safety check
    IF TG_TABLE_NAME = 'user_roles' THEN
      IF TG_OP = 'DELETE' THEN
        IF OLD.user_id IS DISTINCT FROM v_user_id THEN
          RAISE WARNING 'Audit log mismatch: session user_id % != row user_id %', v_user_id, OLD.user_id;
        END IF;
      ELSE
        IF NEW.user_id IS DISTINCT FROM v_user_id THEN
          RAISE WARNING 'Audit log mismatch: session user_id % != row user_id %', v_user_id, NEW.user_id;
        END IF;
      END IF;
    END IF;
  ELSE
    -- No auth context AND no session variable - this should not happen for sensitive operations
    RAISE EXCEPTION 'Audit log failed: no user context available (auth.uid() is NULL and app.current_user_id not set)';
  END IF;

  -- Derive record PK
  IF TG_OP = 'DELETE' THEN
    v_record_id := OLD.id::TEXT;
  ELSE
    v_record_id := NEW.id::TEXT;
  END IF;

  -- Build change payload
  CASE TG_OP
    WHEN 'INSERT' THEN
      v_new_data       := to_jsonb(NEW);
      v_changed_fields := jsonb_build_object('new', v_new_data, 'old', NULL);

    WHEN 'UPDATE' THEN
      v_old_data := to_jsonb(OLD);
      v_new_data := to_jsonb(NEW);
      SELECT jsonb_object_agg(key, value)
      INTO   v_changed_fields
      FROM   jsonb_each(v_new_data)
      WHERE  v_old_data->key IS DISTINCT FROM value;
      v_changed_fields := jsonb_build_object(
        'old',     v_old_data,
        'new',     v_new_data,
        'changed', v_changed_fields
      );

    WHEN 'DELETE' THEN
      v_old_data       := to_jsonb(OLD);
      v_changed_fields := jsonb_build_object('old', v_old_data, 'new', NULL);
  END CASE;

  v_correlation_id := gen_random_uuid();

  INSERT INTO public.audit_logs (
    user_id,
    user_type,
    table_name,
    record_id,
    action,
    changed_fields,
    correlation_id,
    created_at
  ) VALUES (
    v_user_id,       -- Now guaranteed NOT NULL (COALESCE + exception if both sources NULL)
    v_user_type,
    TG_TABLE_NAME,
    v_record_id,
    TG_OP,
    v_changed_fields,
    v_correlation_id,
    NOW()
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

--
-- Name: FUNCTION process_audit_log(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.process_audit_log() IS 'Generic audit trigger with LGPD-compliant user tracking. Uses COALESCE(auth.uid(), current_setting(''app.current_user_id'')) to handle both user-initiated and service-role operations. Raises exception if no user context is available.';
