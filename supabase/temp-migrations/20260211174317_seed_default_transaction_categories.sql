-- ============================================================================
-- Migration: Seed default transaction categories (DEPRECATED - Moved to Seed)
-- ============================================================================
--
-- This migration previously seeded default transaction categories.
-- The seed data has been moved to: supabase/seed.sql (reference values section)
-- under the 'financial_transaction_category' category.
--
-- This file is kept for migration history consistency but no longer contains
-- active seed logic. New deployments receive this data via seed files.
--
-- Note: The financial_transaction_categories table is being deprecated in favor
-- of reference_values for canonical category definitions.

-- No-op: Data migration completed via seed file
SELECT 1;
