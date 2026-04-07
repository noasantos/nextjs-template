-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-28T16:10:00Z
-- Migration: Drop demographic columns from psychologist_patients
-- Purpose: Remove fields not needed for MVP

-- Remove marital status columns
ALTER TABLE IF EXISTS public.psychologist_patients
  DROP COLUMN IF EXISTS manual_marital_status,
  DROP COLUMN IF EXISTS synced_marital_status;

-- Remove education level columns
ALTER TABLE IF EXISTS public.psychologist_patients
  DROP COLUMN IF EXISTS manual_education_level,
  DROP COLUMN IF EXISTS synced_education_level;

-- Remove sexual orientation columns
ALTER TABLE IF EXISTS public.psychologist_patients
  DROP COLUMN IF EXISTS manual_sexual_orientation,
  DROP COLUMN IF EXISTS synced_sexual_orientation;
