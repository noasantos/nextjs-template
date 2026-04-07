-- ============================================================================
-- Migration: Fix weekly consolidation timezone issues and remove obsolete SQL functions
-- 
-- Problem:
-- 1. The TypeScript getWeekRange() function had timezone inconsistencies between
--    local time (getDay()) and UTC (toISOString()), causing week calculations to be off
-- 2. date_time was set to the specific payment date instead of week start, causing
--    lookup failures when searching for existing entries
-- 3. Obsolete SQL functions (consolidate_existing_paid_charges) using different
--    description patterns ("Sessões%" vs "Serviços Prestados%") were creating duplicates
-- 4. Trigger calling non-existent consolidate_weekly_charges() SQL function
--
-- Solution:
-- 1. Remove obsolete SQL functions and triggers
-- 2. Normalize existing financial entries to use week start (Sunday 00:00 UTC)
-- 3. Remove duplicate entries created by inconsistent logic
-- ============================================================================

-- ============================================================================
-- STEP 1: Remove obsolete triggers and functions
-- ============================================================================

-- Drop the trigger that calls the non-existent consolidate_weekly_charges function
DROP TRIGGER IF EXISTS on_charge_paid_consolidate ON public.psychologist_client_charges;
-- Drop the trigger function
DROP FUNCTION IF EXISTS public.trigger_consolidate_weekly_charges() CASCADE;
-- Drop the obsolete consolidate function that uses "Sessões%" description pattern
-- (This was creating duplicates with the TypeScript function that uses "Serviços Prestados%")
DROP FUNCTION IF EXISTS public.consolidate_existing_paid_charges() CASCADE;
-- Drop the cleanup function (no longer needed)
DROP FUNCTION IF EXISTS public.cleanup_orphaned_weekly_consolidations() CASCADE;
-- ============================================================================
-- STEP 2: Create function to fix existing data
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fix_weekly_consolidation_data()
RETURNS TABLE(
  entries_normalized INTEGER,
  duplicates_removed INTEGER,
  orphaned_entries_removed INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_entries_normalized INTEGER := 0;
  v_duplicates_removed INTEGER := 0;
  v_orphaned_removed INTEGER := 0;
  entry_record RECORD;
  week_start TIMESTAMPTZ;
  duplicate_record RECORD;
  existing_entry_id UUID;
  total_amount INTEGER;
  charge_count INTEGER;
BEGIN
  -- ========================================================================
  -- Part A: Normalize date_time to week start (Sunday 00:00 UTC)
  -- ========================================================================
  
  FOR entry_record IN
    SELECT 
      id,
      date_time,
      psychologist_id,
      description,
      amount
    FROM psychologist_financial_entries
    WHERE type = 'income'
      AND (description LIKE 'Serviços Prestados%' OR description LIKE 'Sessões%')
  LOOP
    -- Calculate the Sunday of the week for this entry's date_time
    -- date_trunc('week', ...) returns Monday, so we need to adjust to Sunday
    week_start := date_trunc('week', entry_record.date_time::date)::date - INTERVAL '1 day';
    
    -- If the date is already Sunday, don't go back
    IF extract(dow from entry_record.date_time::date) = 0 THEN
      week_start := entry_record.date_time::date;
    END IF;
    
    -- Set to start of day in UTC
    week_start := week_start::date + INTERVAL '0 hours';
    
    -- Only update if the date_time is different from week_start
    IF entry_record.date_time::date != week_start::date THEN
      UPDATE psychologist_financial_entries
      SET date_time = week_start,
          updated_at = NOW()
      WHERE id = entry_record.id;
      
      v_entries_normalized := v_entries_normalized + 1;
    END IF;
  END LOOP;

  -- ========================================================================
  -- Part B: Merge duplicate entries for the same week
  -- ========================================================================
  
  -- Find all psychologists with potential duplicates
  FOR entry_record IN
    SELECT DISTINCT psychologist_id
    FROM psychologist_financial_entries
    WHERE type = 'income'
      AND (description LIKE 'Serviços Prestados%' OR description LIKE 'Sessões%')
  LOOP
    -- For each week that has multiple entries, merge them
    FOR duplicate_record IN
      SELECT 
        date_trunc('week', date_time::date)::date - INTERVAL '1 day' as week_start_date,
        COUNT(*) as entry_count,
        SUM(amount) as total_amount,
        MIN(id) as keep_id,
        array_agg(id) as all_ids
      FROM psychologist_financial_entries
      WHERE psychologist_id = entry_record.psychologist_id
        AND type = 'income'
        AND (description LIKE 'Serviços Prestados%' OR description LIKE 'Sessões%')
      GROUP BY date_trunc('week', date_time::date)::date - INTERVAL '1 day'
      HAVING COUNT(*) > 1
    LOOP
      -- Update the first entry with the combined amount
      UPDATE psychologist_financial_entries
      SET amount = duplicate_record.total_amount,
          description = 'Serviços Prestados ' || 
            to_char(duplicate_record.week_start_date, 'DD') || ' ' ||
            CASE extract(month from duplicate_record.week_start_date)
              WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
              WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
              WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
              WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
            END || ' - ' ||
            to_char(duplicate_record.week_start_date + 6, 'DD') || ' ' ||
            CASE extract(month from duplicate_record.week_start_date + 6)
              WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
              WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
              WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
              WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
            END,
          date_time = duplicate_record.week_start_date,
          updated_at = NOW()
      WHERE id = duplicate_record.keep_id;
      
      -- Delete the duplicate entries
      DELETE FROM psychologist_financial_entries
      WHERE id = ANY(duplicate_record.all_ids)
        AND id != duplicate_record.keep_id;
      
      v_duplicates_removed := v_duplicates_removed + (array_length(duplicate_record.all_ids, 1) - 1);
    END LOOP;
  END LOOP;

  -- ========================================================================
  -- Part C: Remove orphaned entries (entries with no corresponding paid charges)
  -- ========================================================================
  
  FOR entry_record IN
    SELECT 
      id,
      date_time,
      psychologist_id
    FROM psychologist_financial_entries
    WHERE type = 'income'
      AND (description LIKE 'Serviços Prestados%' OR description LIKE 'Sessões%')
  LOOP
    -- Calculate week range for this entry
    week_start := date_trunc('week', entry_record.date_time::date)::date - INTERVAL '1 day';
    IF extract(dow from entry_record.date_time::date) = 0 THEN
      week_start := entry_record.date_time::date;
    END IF;
    
    -- Count paid charges for this week
    SELECT COUNT(*), COALESCE(SUM(price_cents), 0)
    INTO charge_count, total_amount
    FROM psychologist_client_charges
    WHERE psychologist_id = entry_record.psychologist_id
      AND payment_status = 'paid'
      AND paid_at >= week_start
      AND paid_at < week_start + INTERVAL '7 days';
    
    -- If no charges found, delete the orphaned entry
    IF charge_count = 0 THEN
      DELETE FROM psychologist_financial_entries
      WHERE id = entry_record.id;
      
      v_orphaned_removed := v_orphaned_removed + 1;
    END IF;
  END LOOP;

  -- Return results
  RETURN QUERY SELECT v_entries_normalized, v_duplicates_removed, v_orphaned_removed;
END;
$$;
-- ============================================================================
-- STEP 3: Execute the fix function
-- ============================================================================

-- Run the data fix (comment out if you want to run manually)
SELECT * FROM public.fix_weekly_consolidation_data();
-- ============================================================================
-- STEP 4: Clean up the fix function (optional - remove if you want to keep it)
-- ============================================================================

-- Uncomment the line below to remove the function after execution
-- DROP FUNCTION IF EXISTS public.fix_weekly_consolidation_data();

-- ============================================================================
-- STEP 5: Add comment explaining the consolidation behavior
-- ============================================================================

COMMENT ON TABLE public.psychologist_financial_entries IS 
'Financial transactions (income and expenses) for the psychologist. Focuses on financial health, not patient-specific context. 

Weekly Consolidation:
- Paid charges are consolidated into weekly entries (Sunday to Saturday, UTC)
- The date_time field always stores the Sunday (week start) at 00:00 UTC
- Description format: "Serviços Prestados DD MMM - DD MMM"
- One entry per week per psychologist, updated as charges are paid/unpaid';
