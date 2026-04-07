-- ==========================================================================
-- Migration: Reseed Document Templates from TXT (DEPRECATED - Moved to Seed)
-- ==========================================================================
--
-- This migration previously re-seeded document templates from TXT sources.
-- The seed data has been moved to: supabase/seed.sql (document templates section)
--
-- This file is kept for migration history consistency but no longer contains
-- active seed logic. New deployments receive this data via seed files.

-- No-op: Data migration completed via seed file
SELECT 1;
