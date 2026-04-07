-- migration-created-via: pnpm supabase:migration:new
-- Purpose: Align public.psychologist_patients with production schema (single source of truth).
--   Adds demographic/template columns and all prod columns; safe for local and remote (IF NOT EXISTS).

-- Demographic and template columns (manual/synced pairs + is_minor, treatment_plan, first_session_date)
alter table public.psychologist_patients
  add column if not exists manual_cpf text,
  add column if not exists synced_cpf text,
  add column if not exists manual_rg text,
  add column if not exists synced_rg text,
  add column if not exists manual_gender text,
  add column if not exists synced_gender text,
  add column if not exists manual_pronouns text,
  add column if not exists synced_pronouns text,
  add column if not exists manual_place_of_birth text,
  add column if not exists synced_place_of_birth text,
  add column if not exists manual_marital_status text,
  add column if not exists synced_marital_status text,
  add column if not exists manual_profession text,
  add column if not exists synced_profession text,
  add column if not exists manual_education_level text,
  add column if not exists synced_education_level text,
  add column if not exists manual_sexual_orientation text,
  add column if not exists synced_sexual_orientation text,
  add column if not exists is_minor boolean default false,
  add column if not exists treatment_plan text,
  add column if not exists first_session_date date;
-- Prod columns: address, relationship/discharge, clinical, billing, invite, soft-delete
alter table public.psychologist_patients
  add column if not exists manual_address jsonb,
  add column if not exists relationship_end_date date,
  add column if not exists discharge_reason text,
  add column if not exists requires_legal_guardian boolean default false,
  add column if not exists clinical_notes text,
  add column if not exists disorders jsonb default '[]'::jsonb,
  add column if not exists current_medications jsonb default '[]'::jsonb,
  add column if not exists known_allergies jsonb default '[]'::jsonb,
  add column if not exists suicide_risk_assessment text,
  add column if not exists price_set_at timestamp with time zone,
  add column if not exists price_set_by uuid references public.user_psychologists(id),
  add column if not exists informed_consent_document_url text,
  add column if not exists invite_expires_at timestamp with time zone,
  add column if not exists invite_reminder_sent_at timestamp with time zone,
  add column if not exists invite_reminder_count integer default 0,
  add column if not exists retention_until timestamp with time zone,
  add column if not exists archived_at timestamp with time zone,
  add column if not exists archived_by uuid references public.user_psychologists(id),
  add column if not exists manual_emergency_contacts jsonb,
  add column if not exists attached_documents jsonb default '[]'::jsonb,
  add column if not exists deleted_by uuid references public.user_psychologists(id),
  add column if not exists recovery_deadline timestamp with time zone;
do $$
begin
  if exists (select 1 from pg_type where typname = 'contact_method_type') then
    alter table public.psychologist_patients
      add column if not exists invite_sent_via public.contact_method_type,
      add column if not exists preferred_contact_method public.contact_method_type;
  end if;
end
$$;
comment on column public.psychologist_patients.manual_cpf is 'CPF entered manually by psychologist';
comment on column public.psychologist_patients.synced_cpf is 'CPF synced from external source';
comment on column public.psychologist_patients.manual_rg is 'RG entered manually';
comment on column public.psychologist_patients.synced_rg is 'RG synced from external source';
comment on column public.psychologist_patients.manual_gender is 'Gender entered manually';
comment on column public.psychologist_patients.synced_gender is 'Gender synced from external source';
comment on column public.psychologist_patients.manual_pronouns is 'Pronouns entered manually';
comment on column public.psychologist_patients.synced_pronouns is 'Pronouns synced from external source';
comment on column public.psychologist_patients.manual_place_of_birth is 'Place of birth entered manually';
comment on column public.psychologist_patients.synced_place_of_birth is 'Place of birth synced from external source';
comment on column public.psychologist_patients.manual_marital_status is 'Marital status entered manually';
comment on column public.psychologist_patients.synced_marital_status is 'Marital status synced from external source';
comment on column public.psychologist_patients.manual_profession is 'Profession entered manually';
comment on column public.psychologist_patients.synced_profession is 'Profession synced from external source';
comment on column public.psychologist_patients.manual_education_level is 'Education level entered manually';
comment on column public.psychologist_patients.synced_education_level is 'Education level synced from external source';
comment on column public.psychologist_patients.manual_sexual_orientation is 'Sexual orientation entered manually';
comment on column public.psychologist_patients.synced_sexual_orientation is 'Sexual orientation synced from external source';
comment on column public.psychologist_patients.is_minor is 'Whether the patient is under 18; can be derived from date_of_birth if not set';
comment on column public.psychologist_patients.treatment_plan is 'Treatment plan text for document templates';
comment on column public.psychologist_patients.first_session_date is 'Date of first session with this psychologist';
comment on column public.psychologist_patients.manual_address is 'Manual address (JSON) for document templates';
comment on column public.psychologist_patients.relationship_end_date is 'End date of therapeutic relationship';
comment on column public.psychologist_patients.discharge_reason is 'Reason for discharge if applicable';
comment on column public.psychologist_patients.requires_legal_guardian is 'Whether patient requires legal guardian consent';
comment on column public.psychologist_patients.clinical_notes is 'Private clinical notes';
comment on column public.psychologist_patients.attached_documents is 'Attached documents metadata (JSON array)';
comment on column public.psychologist_patients.recovery_deadline is 'Deadline for soft-delete recovery';
