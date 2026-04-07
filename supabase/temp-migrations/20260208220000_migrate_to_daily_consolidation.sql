-- ============================================================================
-- Migration: Migrate from weekly to daily consolidation
-- 
-- Changes:
-- 1. Update or create "Consolidação Diária" category (replacing "Consolidação Semanal")
-- 2. Update existing entries to use the new category
-- 3. Split weekly consolidated entries into daily entries based on session dates
-- 4. Update descriptions from week range format to daily format
-- ============================================================================

-- ============================================================================
-- STEP 1: Ensure the daily consolidation category exists
-- ============================================================================

-- First, check if "Consolidação Semanal" exists and rename it
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM financial_transaction_categories 
    WHERE name = 'Consolidação Semanal' AND type = 'INCOME'
  ) THEN
    UPDATE financial_transaction_categories
    SET name = 'Consolidação Diária',
        description = 'Receitas consolidadas diariamente baseadas na data de prestação do serviço'
    WHERE name = 'Consolidação Semanal' AND type = 'INCOME';
    
    RAISE NOTICE 'Renamed category from Consolidação Semanal to Consolidação Diária';
  END IF;
END $$;
-- If no consolidation category exists, create it
INSERT INTO financial_transaction_categories (
  name,
  type,
  description,
  is_selectable,
  created_at,
  updated_at
)
SELECT 
  'Consolidação Diária',
  'INCOME',
  'Receitas consolidadas diariamente baseadas na data de prestação do serviço',
  false,
  NOW(),
  NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM financial_transaction_categories 
  WHERE name = 'Consolidação Diária' AND type = 'INCOME'
);
-- ============================================================================
-- STEP 2: Create function to migrate weekly entries to daily
-- ============================================================================

CREATE OR REPLACE FUNCTION public.migrate_weekly_to_daily_consolidation()
RETURNS TABLE(
  entries_migrated INTEGER,
  entries_deleted INTEGER,
  new_daily_entries_created INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
  -- Get the daily consolidation category ID
  SELECT id INTO v_daily_category_id
  FROM financial_transaction_categories
  WHERE name = 'Consolidação Diária' AND type = 'INCOME';
  
  IF v_daily_category_id IS NULL THEN
    RAISE EXCEPTION 'Categoria Consolidação Diária não encontrada';
  END IF;

  -- ========================================================================
  -- Process each weekly consolidated entry
  -- ========================================================================
  
  FOR week_entry IN
    SELECT 
      fe.id as entry_id,
      fe.psychologist_id,
      fe.amount,
      fe.date_time,
      fe.description,
      fe.created_by
    FROM psychologist_financial_entries fe
    WHERE fe.type = 'income'
      AND fe.description LIKE 'Serviços Prestados%'
      AND fe.transaction_category_id = v_daily_category_id
  LOOP
    -- For each week entry, find all paid charges in that week
    -- and regroup them by their session date
    
    FOR session_date IN
      SELECT DISTINCT DATE(cs.start_time) as session_date
      FROM psychologist_client_charges ch
      JOIN clinical_sessions cs ON cs.id = ch.session_id
      WHERE ch.psychologist_id = week_entry.psychologist_id
        AND ch.payment_status = 'paid'
        AND cs.start_time >= week_entry.date_time
        AND cs.start_time < week_entry.date_time + INTERVAL '7 days'
    LOOP
      -- Calculate total for this specific day
      SELECT COALESCE(SUM(ch.price_cents), 0)
      INTO daily_total
      FROM psychologist_client_charges ch
      JOIN clinical_sessions cs ON cs.id = ch.session_id
      WHERE ch.psychologist_id = week_entry.psychologist_id
        AND ch.payment_status = 'paid'
        AND DATE(cs.start_time) = session_date;
      
      -- Check if a daily entry already exists for this date
      SELECT id INTO existing_daily_id
      FROM psychologist_financial_entries
      WHERE psychologist_id = week_entry.psychologist_id
        AND type = 'income'
        AND description LIKE 'Serviços Prestados%'
        AND DATE(date_time) = session_date
      LIMIT 1;
      
      IF existing_daily_id IS NOT NULL THEN
        -- Update existing daily entry
        UPDATE psychologist_financial_entries
        SET amount = daily_total,
            description = 'Serviços Prestados ' || 
              TO_CHAR(session_date, 'DD') || ' ' ||
              CASE EXTRACT(MONTH FROM session_date)
                WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
                WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
                WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
                WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
              END,
            date_time = session_date::TIMESTAMPTZ,
            updated_at = NOW()
        WHERE id = existing_daily_id;
        
        v_entries_migrated := v_entries_migrated + 1;
      ELSE
        -- Create new daily entry
        INSERT INTO psychologist_financial_entries (
          psychologist_id,
          type,
          amount,
          description,
          date_time,
          transaction_category_id,
          status,
          created_by,
          created_at,
          updated_at
        )
        SELECT 
          week_entry.psychologist_id,
          'income',
          daily_total,
          'Serviços Prestados ' || 
            TO_CHAR(session_date, 'DD') || ' ' ||
            CASE EXTRACT(MONTH FROM session_date)
              WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
              WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
              WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
              WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
            END,
          session_date::TIMESTAMPTZ,
          v_daily_category_id,
          'confirmed',
          week_entry.psychologist_id,
          NOW(),
          NOW()
        RETURNING id INTO new_entry_id;
        
        v_new_entries_created := v_new_entries_created + 1;
      END IF;
    END LOOP;
    
    -- Delete the old weekly entry
    DELETE FROM psychologist_financial_entries WHERE id = week_entry.entry_id;
    v_entries_deleted := v_entries_deleted + 1;
  END LOOP;
  
  RETURN QUERY SELECT v_entries_migrated, v_entries_deleted, v_new_entries_created;
END;
$$;
-- ============================================================================
-- STEP 3: Execute the migration (comment out if you want to run manually)
-- ============================================================================

-- Uncomment to run the migration
-- SELECT * FROM public.migrate_weekly_to_daily_consolidation();

-- ============================================================================
-- STEP 4: Clean up old weekly entries that don't have corresponding charges
-- ============================================================================

DELETE FROM psychologist_financial_entries
WHERE type = 'income'
  AND description LIKE 'Serviços Prestados%'
  AND id NOT IN (
    SELECT fe.id
    FROM psychologist_financial_entries fe
    JOIN psychologist_client_charges ch ON ch.psychologist_id = fe.psychologist_id
    JOIN clinical_sessions cs ON cs.id = ch.session_id
    WHERE ch.payment_status = 'paid'
      AND DATE(cs.start_time) = DATE(fe.date_time)
  );
-- ============================================================================
-- STEP 5: Update table comment
-- ============================================================================

COMMENT ON TABLE public.psychologist_financial_entries IS 
'Financial transactions (income and expenses) for the psychologist. Focuses on financial health, not patient-specific context. 

Daily Consolidation:
- Paid charges are consolidated into daily entries based on SESSION DATE (data de prestação do serviço)
- The date_time field always stores the day of service delivery at 00:00 UTC
- Description format: "Serviços Prestados DD MMM"
- One entry per day per psychologist, updated as charges are paid/unpaid';
-- ============================================================================
-- STEP 6: Drop the migration function after use (optional)
-- ============================================================================

-- Uncomment to clean up after migration
-- DROP FUNCTION IF EXISTS public.migrate_weekly_to_daily_consolidation();;
