-- Fix remaining stale FK constraint names after table/column renames.
-- The code references these via PostgREST !hint syntax; DB names must match.

-- psychologist_notes: clinical_notes_* → psychologist_notes_*
alter table public.psychologist_notes
  rename constraint clinical_notes_patient_id_fkey
  to psychologist_notes_patient_id_fkey;
alter table public.psychologist_notes
  rename constraint clinical_notes_session_id_fkey
  to psychologist_notes_session_id_fkey;
-- public_locations: psychologist_locations_psychologist_id_fkey → public_locations_psychologist_id_fkey
alter table public.public_locations
  rename constraint psychologist_locations_psychologist_id_fkey
  to public_locations_psychologist_id_fkey;
notify pgrst, 'reload schema';
