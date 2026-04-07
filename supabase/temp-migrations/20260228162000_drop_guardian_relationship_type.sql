-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-28T16:20:00Z
-- Migration: Drop relationship_type from psychologist_patient_guardians
-- Purpose: Remove redundant field - use guardian_type instead

ALTER TABLE IF EXISTS public.psychologist_patient_guardians
  DROP COLUMN IF EXISTS relationship_type;
