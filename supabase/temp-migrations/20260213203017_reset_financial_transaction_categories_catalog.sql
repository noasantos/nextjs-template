-- ==========================================================================
-- Migration: Reset Financial Transaction Categories (DEPRECATED - Moved to Seed)
-- ==========================================================================
--
-- This migration previously reset and re-seeded financial transaction categories.
-- The seed data has been moved to: supabase/seed.sql (reference values section)
--
-- This file is kept for migration history consistency but no longer contains
-- active seed logic. New deployments receive this data via seed files.
--
-- The reference_values table now contains canonical financial transaction categories
-- under the 'financial_transaction_category' category.

-- No-op: Data migration completed via seed file
SELECT 1;
