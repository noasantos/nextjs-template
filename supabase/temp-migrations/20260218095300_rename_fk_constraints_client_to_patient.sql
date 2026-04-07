-- Rename FK constraints to match new column names (client → patient).
-- These were missed when columns were renamed in 20260217200722.
-- The application queries reference the new names via PostgREST !hint syntax.

-- psychologist_clinical_sessions: psychologist_client_id → psychologist_patient_id
alter table public.psychologist_clinical_sessions
  rename constraint clinical_sessions_psychologist_client_id_fkey
  to clinical_sessions_psychologist_patient_id_fkey;
-- psychologist_patient_charges: psychologist_client_id → psychologist_patient_id
alter table public.psychologist_patient_charges
  rename constraint psychologist_client_charges_psychologist_client_id_fkey
  to psychologist_client_charges_psychologist_patient_id_fkey;
-- Reload PostgREST schema cache so the renamed constraints are visible immediately
notify pgrst, 'reload schema';
