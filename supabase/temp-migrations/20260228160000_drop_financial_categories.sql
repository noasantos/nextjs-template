-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-28T16:00:00Z
-- Migration: Drop financial_categories table
-- Purpose: Remove redundant table - use reference_values instead

-- Remove FK constraint from psychologist_financial_entries first
ALTER TABLE IF EXISTS public.psychologist_financial_entries
  DROP CONSTRAINT IF EXISTS psychologist_financial_entries_category_id_fkey;

-- Remove category_id column from psychologist_financial_entries
-- (transaction_category_id should be used instead, referencing reference_values)
ALTER TABLE IF EXISTS public.psychologist_financial_entries
  DROP COLUMN IF EXISTS category_id;

-- Drop the table
DROP TABLE IF EXISTS public.financial_categories CASCADE;

-- Drop any remaining indexes
DROP INDEX IF EXISTS idx_financial_categories_psychologist_id;
DROP INDEX IF EXISTS idx_financial_categories_lookup;
