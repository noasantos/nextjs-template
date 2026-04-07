-- migration-created-via: pnpm supabase:migration:new
-- Migration: fix_psychologist_client_charges_references
-- Description: Fixes references to the renamed table psychologist_client_charges -> psychologist_patient_charges
-- This migration is idempotent and can be applied to any environment.

DO $$ 
BEGIN
    -------------------------------------------------------------------------------
    -- 1. FIX FUNCTIONS
    -------------------------------------------------------------------------------

    -- Fix consolidate_daily_charges
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'consolidate_daily_charges') THEN
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
        $function$;
    END IF;

    -- Fix migrate_weekly_to_daily_consolidation
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'migrate_weekly_to_daily_consolidation') THEN
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
        $function$;
    END IF;

    -- Fix process_pending_session_billing
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'process_pending_session_billing') THEN
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
    END IF;

    -- Fix recalculate_daily_consolidation_for_charge
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'recalculate_daily_consolidation_for_charge') THEN
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
          FROM public.psychologist_patient_charges c
          JOIN public.psychologist_clinical_sessions s ON s.id = c.session_id
          WHERE c.id = p_charge_id;
          
          IF v_psychologist_id IS NULL THEN
            RETURN;
          END IF;
          
          RETURN QUERY SELECT * FROM public.consolidate_daily_charges(v_psychologist_id, v_session_date);
        END;
        $function$;
    END IF;

    -------------------------------------------------------------------------------
    -- 2. FIX TRIGGERS (RECREATE IF NECESSARY)
    -------------------------------------------------------------------------------
    
    -- Triggers usually reference the table directly. If the table was renamed, 
    -- the trigger might need to be dropped and recreated on the new table.
    
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_patient_charges' AND schemaname = 'public') THEN
        -- Example trigger cleanup if it was still pointing to the old name or failed
        DROP TRIGGER IF EXISTS on_charge_paid_consolidate ON public.psychologist_patient_charges;
        
        IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_on_charge_paid_consolidate') THEN
            CREATE TRIGGER on_charge_paid_consolidate
            AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_patient_charges
            FOR EACH ROW EXECUTE FUNCTION public.fn_on_charge_paid_consolidate();
        END IF;
    END IF;

END $$;
