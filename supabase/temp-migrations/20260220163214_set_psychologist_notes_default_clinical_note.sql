-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-20T16:32:14Z

-- Set remote-aligned default after enum value has been committed by prior migration.
alter table if exists public.psychologist_notes
  alter column note_type set default 'clinical_note'::public.clinical_note_type;
