-- migration-created-via: pnpm supabase:migration:new
-- Purpose: Fix RLS on psychologist_patient_emergency_contacts for patient page scope.
-- The table was renamed from patient_emergency_contacts and the column from
-- psychologist_client_id to psychologist_patient_id; the old policy still
-- references psychologist_clients and psychologist_client_id, which are invalid.
-- This migration drops the broken policy and creates a correct one using
-- psychologist_patients and psychologist_patient_id.
-- Affected: public.psychologist_patient_emergency_contacts
--
-- Idempotent: safe to re-run if already applied on remote (stg/main) or local.
-- Only runs when table psychologist_patient_emergency_contacts exists.

do $$
begin
  if exists (
    select 1 from pg_tables
    where schemaname = 'public' and tablename = 'psychologist_patient_emergency_contacts'
  ) then
    ---------------------------------------------------------------------------
    -- 1. Drop broken or existing policy (no-op if already dropped)
    ---------------------------------------------------------------------------
    drop policy if exists "Psychologists can manage patient emergency contacts"
      on public.psychologist_patient_emergency_contacts;

    ---------------------------------------------------------------------------
    -- 2. Create policy: access only when the emergency contact belongs to a
    --    psychologist_patients row owned by the current user
    ---------------------------------------------------------------------------
    create policy "Psychologists can manage patient emergency contacts"
      on public.psychologist_patient_emergency_contacts
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.psychologist_patients pp
          where pp.id = psychologist_patient_emergency_contacts.psychologist_patient_id
            and pp.psychologist_id = (select auth.uid())
        )
      )
      with check (
        exists (
          select 1
          from public.psychologist_patients pp
          where pp.id = psychologist_patient_emergency_contacts.psychologist_patient_id
            and pp.psychologist_id = (select auth.uid())
        )
      );

    comment on policy "Psychologists can manage patient emergency contacts"
      on public.psychologist_patient_emergency_contacts is
      'Allow psychologists to manage emergency contacts only for their own patients (via psychologist_patients)';

    ---------------------------------------------------------------------------
    -- 3. Index for list/delete by psychologist_patient_id (if not exists)
    ---------------------------------------------------------------------------
    create index if not exists idx_psychologist_patient_emergency_contacts_psychologist_patient_id
      on public.psychologist_patient_emergency_contacts (psychologist_patient_id);
  end if;
end
$$;
