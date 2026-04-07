-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-20T16:25:41Z

-- Ensure local schema contains session_reschedule_logs (present in production snapshot).
-- Idempotent migration: safe when table/constraints/policies already exist.

create table if not exists public.session_reschedule_logs (
  id uuid not null default gen_random_uuid(),
  session_id uuid not null,
  from_start_time timestamp with time zone not null,
  to_start_time timestamp with time zone not null,
  from_duration_minutes integer,
  to_duration_minutes integer,
  reason text,
  created_at timestamp with time zone default now(),
  created_by uuid,
  constraint session_reschedule_logs_pkey primary key (id)
);
alter table if exists public.session_reschedule_logs
  add column if not exists session_id uuid,
  add column if not exists from_start_time timestamp with time zone,
  add column if not exists to_start_time timestamp with time zone,
  add column if not exists from_duration_minutes integer,
  add column if not exists to_duration_minutes integer,
  add column if not exists reason text,
  add column if not exists created_at timestamp with time zone default now(),
  add column if not exists created_by uuid;
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'session_reschedule_logs'
      and column_name = 'from_start_time'
      and is_nullable = 'YES'
  ) then
    alter table public.session_reschedule_logs
      alter column from_start_time set not null;
  end if;
end $$;
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'session_reschedule_logs'
      and column_name = 'to_start_time'
      and is_nullable = 'YES'
  ) then
    alter table public.session_reschedule_logs
      alter column to_start_time set not null;
  end if;
end $$;
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'session_reschedule_logs'
      and column_name = 'session_id'
      and is_nullable = 'YES'
  ) then
    alter table public.session_reschedule_logs
      alter column session_id set not null;
  end if;
end $$;
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'session_reschedule_logs_session_id_fkey'
      and conrelid = 'public.session_reschedule_logs'::regclass
  ) then
    alter table public.session_reschedule_logs
      add constraint session_reschedule_logs_session_id_fkey
      foreign key (session_id)
      references public.psychologist_clinical_sessions(id);
  end if;
end $$;
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'session_reschedule_logs_created_by_fkey'
      and conrelid = 'public.session_reschedule_logs'::regclass
  ) then
    alter table public.session_reschedule_logs
      add constraint session_reschedule_logs_created_by_fkey
      foreign key (created_by)
      references public.user_psychologists(id);
  end if;
end $$;
create index if not exists idx_session_reschedule_logs_created_by
  on public.session_reschedule_logs(created_by);
create index if not exists idx_session_reschedule_logs_session_id
  on public.session_reschedule_logs(session_id);
alter table if exists public.session_reschedule_logs enable row level security;
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'session_reschedule_logs'
      and policyname = 'reschedule_logs_owner_access'
  ) then
    create policy "reschedule_logs_owner_access"
      on public.session_reschedule_logs
      for all
      to authenticated
      using (
        exists (
          select 1
          from public.psychologist_clinical_sessions pcs
          where pcs.id = session_id
            and pcs.psychologist_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.psychologist_clinical_sessions pcs
          where pcs.id = session_id
            and pcs.psychologist_id = auth.uid()
        )
      );
  end if;
end $$;
