-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-20T16:49:14Z

-- Reconcile stale legacy patient/document tables with the current app contract.
-- Additive and idempotent only.

alter table if exists public.psychologist_patient_guardians
  add column if not exists full_name text,
  add column if not exists guardian_type text,
  add column if not exists relationship_type text,
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists cpf text,
  add column if not exists rg text,
  add column if not exists date_of_birth date,
  add column if not exists street text,
  add column if not exists number text,
  add column if not exists complement text,
  add column if not exists neighborhood text,
  add column if not exists city text,
  add column if not exists state text,
  add column if not exists postal_code text,
  add column if not exists country text default 'Brasil'::text,
  add column if not exists status text default 'active'::text;
alter table if exists public.psychologist_patient_assessments
  add column if not exists patient_id uuid,
  add column if not exists test_id uuid,
  add column if not exists test_name text,
  add column if not exists test_type text,
  add column if not exists test_date date,
  add column if not exists applied_at timestamp with time zone,
  add column if not exists results text,
  add column if not exists interpretation text,
  add column if not exists psychologist_notes text,
  add column if not exists notes text,
  add column if not exists file_url text,
  add column if not exists clinical_note_id uuid,
  add column if not exists status text default 'pending'::text,
  add column if not exists tags text[],
  add column if not exists is_archived boolean default false,
  add column if not exists created_by uuid,
  add column if not exists updated_by uuid;
alter table if exists public.psychologist_patient_activities
  add column if not exists patient_id uuid,
  add column if not exists activity_id uuid,
  add column if not exists assigned_at timestamp with time zone default now(),
  add column if not exists due_date date,
  add column if not exists instructions text,
  add column if not exists status text default 'pending'::text,
  add column if not exists is_archived boolean default false,
  add column if not exists patient_feedback text,
  add column if not exists therapist_comment text,
  add column if not exists created_by uuid,
  add column if not exists updated_by uuid,
  add column if not exists completed_at timestamp with time zone;
alter table if exists public.psychologist_patient_medical_items
  add column if not exists start_date date,
  add column if not exists end_date date;
alter table if exists public.psychologist_clinical_sessions
  add column if not exists note_id uuid;
alter table if exists public.generated_documents
  add column if not exists patient_id uuid,
  add column if not exists template_id uuid,
  add column if not exists document_type text,
  add column if not exists encoded_content text default ''::text,
  add column if not exists tags text[],
  add column if not exists is_archived boolean default false;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'psychologist_patient_assessments_patient_id_fkey'
      and conrelid = 'public.psychologist_patient_assessments'::regclass
  ) then
    alter table public.psychologist_patient_assessments
      add constraint psychologist_patient_assessments_patient_id_fkey
      foreign key (patient_id) references public.psychologist_patients(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'patient_tests_clinical_note_id_fkey'
      and conrelid = 'public.psychologist_patient_assessments'::regclass
  ) then
    alter table public.psychologist_patient_assessments
      add constraint patient_tests_clinical_note_id_fkey
      foreign key (clinical_note_id) references public.psychologist_notes(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'patient_tests_created_by_fkey'
      and conrelid = 'public.psychologist_patient_assessments'::regclass
  ) then
    alter table public.psychologist_patient_assessments
      add constraint patient_tests_created_by_fkey
      foreign key (created_by) references public.user_psychologists(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'patient_tests_updated_by_fkey'
      and conrelid = 'public.psychologist_patient_assessments'::regclass
  ) then
    alter table public.psychologist_patient_assessments
      add constraint patient_tests_updated_by_fkey
      foreign key (updated_by) references public.user_psychologists(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'patient_activity_assignments_patient_id_fkey'
      and conrelid = 'public.psychologist_patient_activities'::regclass
  ) then
    alter table public.psychologist_patient_activities
      add constraint patient_activity_assignments_patient_id_fkey
      foreign key (patient_id) references public.psychologist_patients(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'patient_activity_assignments_activity_id_fkey'
      and conrelid = 'public.psychologist_patient_activities'::regclass
  ) then
    alter table public.psychologist_patient_activities
      add constraint patient_activity_assignments_activity_id_fkey
      foreign key (activity_id) references public.catalog_clinical_activities(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'patient_activity_assignments_created_by_fkey'
      and conrelid = 'public.psychologist_patient_activities'::regclass
  ) then
    alter table public.psychologist_patient_activities
      add constraint patient_activity_assignments_created_by_fkey
      foreign key (created_by) references public.user_psychologists(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'patient_activity_assignments_updated_by_fkey'
      and conrelid = 'public.psychologist_patient_activities'::regclass
  ) then
    alter table public.psychologist_patient_activities
      add constraint patient_activity_assignments_updated_by_fkey
      foreign key (updated_by) references public.user_psychologists(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'clinical_sessions_note_id_fkey'
      and conrelid = 'public.psychologist_clinical_sessions'::regclass
  ) then
    alter table public.psychologist_clinical_sessions
      add constraint clinical_sessions_note_id_fkey
      foreign key (note_id) references public.psychologist_notes(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'generated_documents_patient_id_fkey'
      and conrelid = 'public.generated_documents'::regclass
  ) then
    alter table public.generated_documents
      add constraint generated_documents_patient_id_fkey
      foreign key (patient_id) references public.psychologist_patients(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'generated_documents_template_id_fkey'
      and conrelid = 'public.generated_documents'::regclass
  ) then
    alter table public.generated_documents
      add constraint generated_documents_template_id_fkey
      foreign key (template_id) references public.catalog_document_templates(id);
  end if;
end $$;
create index if not exists idx_psych_patient_assessments_patient_id
  on public.psychologist_patient_assessments(patient_id);
create index if not exists idx_psych_patient_activities_patient_id
  on public.psychologist_patient_activities(patient_id);
create index if not exists idx_psych_patient_activities_activity_id
  on public.psychologist_patient_activities(activity_id);
create index if not exists idx_generated_documents_patient_id
  on public.generated_documents(patient_id);
create index if not exists idx_generated_documents_template_id
  on public.generated_documents(template_id);
create index if not exists idx_psych_clinical_sessions_note_id
  on public.psychologist_clinical_sessions(note_id);
create or replace function public.sync_user_app_metadata(
  p_onboarding_completed boolean default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  update auth.users
  set raw_app_meta_data = case
    when p_onboarding_completed is null then coalesce(raw_app_meta_data, '{}'::jsonb)
    else jsonb_set(
      coalesce(raw_app_meta_data, '{}'::jsonb),
      '{onboarding_completed}',
      to_jsonb(p_onboarding_completed),
      true
    )
  end
  where id = v_user_id;
end;
$$;
drop function if exists public.get_psychologist_availability(uuid, date, date);
create or replace function public.get_psychologist_availability(
  p_psychologist_id uuid,
  p_start_date date,
  p_end_date date
)
returns table (
  date date,
  day_of_week integer,
  start_time time without time zone,
  end_time time without time zone,
  location_id uuid,
  delivery_mode public.delivery_mode,
  available_for_first_appointment boolean,
  is_exception boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with days as (
    select gs::date as slot_date
    from generate_series(p_start_date, p_end_date, interval '1 day') as gs
  ),
  base_slots as (
    select
      d.slot_date as date,
      pws.day_of_week,
      pws.start_time,
      pws.end_time,
      pws.location_id,
      pws.delivery_mode,
      coalesce(pws.available_for_first_appointment, true) as available_for_first_appointment,
      false as is_exception
    from days d
    join public.psychologist_weekly_schedules pws
      on pws.psychologist_id = p_psychologist_id
      and pws.is_active = true
      and pws.day_of_week = extract(dow from d.slot_date)::int
      and (pws.effective_start is null or pws.effective_start <= d.slot_date)
      and (pws.effective_end is null or pws.effective_end >= d.slot_date)
    left join public.availability_exceptions ae
      on ae.psychologist_id = p_psychologist_id
      and ae.exception_date = d.slot_date
    where coalesce(ae.is_available, true) = true
  ),
  exception_slots as (
    select
      ae.exception_date as date,
      extract(dow from ae.exception_date)::int as day_of_week,
      ae.start_time,
      ae.end_time,
      null::uuid as location_id,
      null::public.delivery_mode as delivery_mode,
      true as available_for_first_appointment,
      true as is_exception
    from public.availability_exceptions ae
    where ae.psychologist_id = p_psychologist_id
      and ae.exception_date between p_start_date and p_end_date
      and ae.is_available = true
      and ae.start_time is not null
      and ae.end_time is not null
  )
  select * from base_slots
  union all
  select * from exception_slots
  order by date, start_time;
$$;
grant execute on function public.sync_user_app_metadata(boolean) to authenticated;
grant execute on function public.get_psychologist_availability(uuid, date, date) to anon, authenticated, service_role;
