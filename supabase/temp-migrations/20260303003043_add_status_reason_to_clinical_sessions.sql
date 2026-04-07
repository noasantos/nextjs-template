-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-03-03T00:30:43Z

-- Add status_reason column to psychologist_clinical_sessions
-- Used by manage-status.ts when changing session status (cancel, no_show, etc.)
ALTER TABLE public.psychologist_clinical_sessions
  ADD COLUMN IF NOT EXISTS status_reason text;
