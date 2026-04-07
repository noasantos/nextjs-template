-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-03-03T00:28:38Z

-- Make patient_id nullable on clinical_session_details.
-- Manually-created patients (psychologist_patients) may not have a linked
-- user_patients record, so the FK to user_patients cannot always be populated.
ALTER TABLE public.clinical_session_details
  ALTER COLUMN patient_id DROP NOT NULL;
