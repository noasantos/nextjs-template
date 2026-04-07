-- ==========================================================================
-- Migration: Seed Reference Values - Cancellation Policies (DEPRECATED)
-- ==========================================================================
--
-- This migration previously seeded reference values including:
-- - Cancellation policies
-- - Financial transaction categories
-- - Psychology specialties
-- - Psychological approaches
-- - Psychological service types
--
-- The seed data has been moved to: supabase/seed.sql (reference values section)
--
-- This file is kept for migration history consistency but no longer contains
-- active seed logic. New deployments receive this data via seed files.

-- No-op: Data migration completed via seed file
SELECT 1;
