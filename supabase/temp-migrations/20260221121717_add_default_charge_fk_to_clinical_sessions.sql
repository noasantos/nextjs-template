-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-21T12:17:17Z

alter table public.psychologist_clinical_sessions
  drop constraint if exists clinical_sessions_default_charge_id_fkey;
alter table public.psychologist_clinical_sessions
  add constraint clinical_sessions_default_charge_id_fkey
  foreign key (default_charge_id)
  references public.psychologist_patient_charges (id)
  on delete set null;
