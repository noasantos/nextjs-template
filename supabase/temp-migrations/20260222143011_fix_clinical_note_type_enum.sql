-- migration-created-via: pnpm supabase:migration:new
-- Migration: fix_clinical_note_type_enum
-- Simplifies clinical_note_type enum to two values:
--   clinical_note: clinical note (never has parent_note_id)
--   progress_note: progress note (may have parent_note_id for chaining)
-- Idempotent: safe to run multiple times.

-- =============================================================================
-- STEP 0: Ensure psychologist_notes table exists with note_type column
-- =============================================================================
do $$
begin
    -- Ensure table exists
    if not exists (
        select 1 from information_schema.tables 
        where table_schema = 'public' and table_name = 'psychologist_notes'
    ) then
        create table public.psychologist_notes (
            id uuid primary key default gen_random_uuid(),
            psychologist_id uuid not null references public.user_psychologists(id) on delete cascade,
            patient_id uuid references public.psychologist_patients(id) on delete set null,
            session_id uuid references public.psychologist_clinical_sessions(id) on delete set null,
            title text not null,
            content text,
            note_type text default 'clinical_note',
            parent_note_id uuid references public.psychologist_notes(id) on delete set null,
            created_at timestamp with time zone default now(),
            updated_at timestamp with time zone default now()
        );
    end if;
end $$;
-- =============================================================================
-- STEP 1: Create new enum if it does not exist
-- =============================================================================
do $$
begin
    if not exists (
        select 1 from pg_type t
        join pg_namespace n on t.typnamespace = n.oid
        where n.nspname = 'public' and t.typname = 'clinical_note_type_new'
    ) then
        create type public.clinical_note_type_new as enum ('clinical_note', 'progress_note');
    end if;
end $$;
-- =============================================================================
-- STEP 2: Migrate column when it still uses the old enum (no UPDATE across types;
-- do value mapping inside ALTER COLUMN ... USING to avoid type mismatch)
-- =============================================================================
do $$
declare
    v_old_enum_exists boolean;
    v_column_uses_old_enum boolean;
begin
    select exists (
        select 1 from pg_type t
        join pg_namespace n on t.typnamespace = n.oid
        where n.nspname = 'public' and t.typname = 'clinical_note_type'
    ) into v_old_enum_exists;

    select exists (
        select 1 from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = 'psychologist_notes'
          and c.column_name = 'note_type'
          and c.udt_name = 'clinical_note_type'
    ) into v_column_uses_old_enum;

    if v_old_enum_exists and v_column_uses_old_enum then
        -- Drop default first to avoid cast issues, then alter column, then restore default
        alter table public.psychologist_notes alter column note_type drop default;
        
        -- Change column type and map deprecated values in one step (USING clause)
        alter table public.psychologist_notes
            alter column note_type type public.clinical_note_type_new
            using (
                case
                    when note_type::text in ('session_note', 'hypothesis', 'treatment_plan', 'risk_assessment', 'test_result') or note_type is null
                    then 'clinical_note'::public.clinical_note_type_new
                    else note_type::text::public.clinical_note_type_new
                end
            );

        drop type if exists public.clinical_note_type cascade;
        alter type public.clinical_note_type_new rename to clinical_note_type;
    elsif not v_old_enum_exists then
        if exists (
            select 1 from pg_type t
            join pg_namespace n on t.typnamespace = n.oid
            where n.nspname = 'public' and t.typname = 'clinical_note_type'
        ) then
            null;
        elsif exists (
            select 1 from pg_type t
            join pg_namespace n on t.typnamespace = n.oid
            where n.nspname = 'public' and t.typname = 'clinical_note_type_new'
        ) then
            alter type public.clinical_note_type_new rename to clinical_note_type;
        else
            create type public.clinical_note_type as enum ('clinical_note', 'progress_note');
        end if;
    end if;
end $$;
-- =============================================================================
-- STEP 3: Ensure column uses the correct enum type
-- =============================================================================
do $$
declare
    v_column_type text;
begin
    select c.udt_name into v_column_type
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'psychologist_notes'
      and c.column_name = 'note_type';

    if v_column_type is null then
        alter table public.psychologist_notes
            add column note_type public.clinical_note_type default 'clinical_note';
    elsif v_column_type != 'clinical_note_type' then
        -- Drop default first to avoid cast issues
        alter table public.psychologist_notes alter column note_type drop default;
        -- Change column type
        alter table public.psychologist_notes
            alter column note_type type public.clinical_note_type
            using coalesce(note_type::text, 'clinical_note')::public.clinical_note_type;
    end if;
end $$;
-- =============================================================================
-- STEP 4: Set default
-- =============================================================================
alter table public.psychologist_notes
    alter column note_type set default 'clinical_note'::public.clinical_note_type;
-- =============================================================================
-- STEP 5: Drop temporary type if it still exists
-- =============================================================================
drop type if exists public.clinical_note_type_new cascade;
-- =============================================================================
-- STEP 6: Fix inconsistent data before applying constraint
-- Records with note_type='clinical_note' and parent_note_id NOT NULL
-- should be converted to 'progress_note' (as they have a parent)
-- Note: Set app.current_user_id to migration context for audit logging
-- =============================================================================
-- Set app.current_user_id for audit logging (uses NULL UUID for system operations)
select set_config('app.current_user_id', '00000000-0000-0000-0000-000000000000', true);

update public.psychologist_notes
set note_type = 'progress_note'::public.clinical_note_type
where note_type = 'clinical_note'::public.clinical_note_type
  and parent_note_id is not null;

-- =============================================================================
-- STEP 7: Add check constraint for business rule
-- =============================================================================
do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'clinical_note_no_parent_check'
          and conrelid = 'public.psychologist_notes'::regclass
    ) then
        alter table public.psychologist_notes
        add constraint clinical_note_no_parent_check
        check (
            (note_type = 'clinical_note' and parent_note_id is null) or
            (note_type = 'progress_note')
        );
    end if;
end $$;
-- =============================================================================
-- STEP 8: Ensure any remaining NULLs are set to default
-- =============================================================================
update public.psychologist_notes
set note_type = 'clinical_note'::public.clinical_note_type
where note_type is null;
-- =============================================================================
-- STEP 9: Add comments
-- =============================================================================
comment on type public.clinical_note_type is 'Psychologist note types: clinical_note (standalone) or progress_note (may chain via parent_note_id)';
comment on column public.psychologist_notes.note_type is 'Note type: clinical_note (no parent_note_id) or progress_note (may have parent_note_id)';
comment on column public.psychologist_notes.parent_note_id is 'Self-reference for progress_note chaining. Always NULL for clinical_note.';
