-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-20T17:11:03Z
-- migration-created-via: pnpm supabase:migration:new
-- Purpose: Reconcile additional local schema gaps against remote production schema.

-- 1) catalog_document_templates
alter table if exists public.catalog_document_templates
  add column if not exists usage_count integer default 0;
-- 2) psychologist_patients
alter table if exists public.psychologist_patients
  add column if not exists synced_address jsonb;
-- 3) psychologist_financial_entries
alter table if exists public.psychologist_financial_entries
  add column if not exists notes text,
  add column if not exists billing_id uuid;
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'psychologist_financial_entries_billing_id_fkey'
      and conrelid = 'public.psychologist_financial_entries'::regclass
  ) then
    alter table public.psychologist_financial_entries
      add constraint psychologist_financial_entries_billing_id_fkey
      foreign key (billing_id) references public.psychologist_patient_charges(id);
  end if;
end
$$;
-- 4) psychologist_patient_guardian_documents
alter table if exists public.psychologist_patient_guardian_documents
  add column if not exists title text,
  add column if not exists document_type text,
  add column if not exists description text,
  add column if not exists file_name text,
  add column if not exists file_size integer,
  add column if not exists mime_type text,
  add column if not exists uploaded_at timestamp with time zone default now(),
  add column if not exists expires_at timestamp with time zone,
  add column if not exists status text default 'active';
update public.psychologist_patient_guardian_documents
set title = coalesce(title, 'Documento'),
    document_type = coalesce(document_type, 'other'),
    file_name = coalesce(file_name, 'arquivo'),
    status = coalesce(status, 'active')
where title is null
   or document_type is null
   or file_name is null
   or status is null;
alter table public.psychologist_patient_guardian_documents
  alter column title set not null,
  alter column document_type set not null,
  alter column file_name set not null,
  alter column status set not null;
do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'psychologist_patient_guardian_documents_patient_id_fkey'
      and conrelid = 'public.psychologist_patient_guardian_documents'::regclass
  ) then
    alter table public.psychologist_patient_guardian_documents
      drop constraint psychologist_patient_guardian_documents_patient_id_fkey;
  end if;
end
$$;
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'psychologist_patient_guardian_documents_patient_id_fkey'
      and conrelid = 'public.psychologist_patient_guardian_documents'::regclass
  ) then
    alter table public.psychologist_patient_guardian_documents
      add constraint psychologist_patient_guardian_documents_patient_id_fkey
      foreign key (patient_id) references public.psychologist_patients(id);
  end if;
end
$$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'psychologist_patient_guardian_documents_document_type_check'
      and conrelid = 'public.psychologist_patient_guardian_documents'::regclass
  ) then
    alter table public.psychologist_patient_guardian_documents
      add constraint psychologist_patient_guardian_documents_document_type_check
      check (
        document_type = any (
          array[
            'power_of_attorney',
            'custody',
            'authorization',
            'id_document',
            'consent',
            'other'
          ]
        )
      );
  end if;
end
$$;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'psychologist_patient_guardian_documents_status_check'
      and conrelid = 'public.psychologist_patient_guardian_documents'::regclass
  ) then
    alter table public.psychologist_patient_guardian_documents
      add constraint psychologist_patient_guardian_documents_status_check
      check (status = any (array['active', 'expired', 'revoked']));
  end if;
end
$$;
-- 5) public_linktree_links
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'public_linktree_links'
      and column_name = 'display_order'
  ) then
    execute $sql$
      update public.public_linktree_links
      set title = coalesce(title, 'Link'),
          url = coalesce(url, '#'),
          is_active = coalesce(is_active, true),
          sort_order = coalesce(sort_order, display_order, 0)
      where title is null
         or url is null
         or is_active is null
         or sort_order is null
    $sql$;
  else
    update public.public_linktree_links
    set title = coalesce(title, 'Link'),
        url = coalesce(url, '#'),
        is_active = coalesce(is_active, true),
        sort_order = coalesce(sort_order, 0)
    where title is null
       or url is null
       or is_active is null
       or sort_order is null;
  end if;
end
$$;
alter table public.public_linktree_links
  alter column title set default 'Link',
  alter column url set default '#',
  alter column is_active set default true,
  alter column sort_order set default 0;
alter table public.public_linktree_links
  alter column title set not null,
  alter column url set not null,
  alter column is_active set not null,
  alter column sort_order set not null;
