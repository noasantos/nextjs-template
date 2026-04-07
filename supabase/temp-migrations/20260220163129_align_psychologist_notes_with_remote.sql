-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-20T16:31:29Z

-- Align psychologist_notes with remote production contract while preserving local extras.
-- Idempotent and additive-safe.

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_enum e on e.enumtypid = t.oid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'clinical_note_type'
      and e.enumlabel = 'clinical_note'
  ) then
    alter type public.clinical_note_type add value 'clinical_note';
  end if;
end $$;
alter table if exists public.psychologist_notes
  alter column encoded_content set default ''::text;
update public.psychologist_notes
set encoded_content = ''
where encoded_content is null;
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_notes'
      and column_name = 'encoded_content'
      and is_nullable = 'YES'
  ) then
    alter table public.psychologist_notes
      alter column encoded_content set not null;
  end if;
end $$;
