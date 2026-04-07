-- ============================================================================
-- Migration: Remove Recurring Transactions Feature
-- 
-- Removes all recurring transaction functionality from the database.
-- This includes the table, triggers, functions, and related constraints.
-- ============================================================================

-- Drop triggers only if the table exists
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'recurring_transactions') THEN
    DROP TRIGGER IF EXISTS on_recurring_transaction_insert ON public.recurring_transactions;
    DROP TRIGGER IF EXISTS on_recurring_transaction_update ON public.recurring_transactions;
  END IF;
END $$;
-- Drop trigger functions
DROP FUNCTION IF EXISTS public.handle_recurring_transaction_insert() CASCADE;
DROP FUNCTION IF EXISTS public.handle_recurring_transaction_update() CASCADE;
DROP FUNCTION IF EXISTS public.generate_recurring_transaction_occurrences() CASCADE;
-- Drop the main table (this will also drop associated constraints and indexes)
DROP TABLE IF EXISTS public.recurring_transactions CASCADE;
-- Remove any RLS policies that might exist for the table (they should be dropped with the table, but just to be safe)
-- Note: Policies are automatically dropped when the table is dropped

-- Update comments on related tables to remove references to recurring transactions
COMMENT ON TABLE public.psychologist_financial_entries IS 
'Financial transactions (income and expenses) for the psychologist.

Daily Consolidation:
- Paid charges are consolidated into daily entries based on session date
- The date_time field stores the session date at 00:00 UTC
- Description format: "Serviços Prestados DD MMM"
- One entry per day per psychologist, updated as charges are paid/unpaid';
