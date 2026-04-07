-- migration-created-via: pnpm supabase:migration:new
-- 1) Fix is_profile_public to use public.public_profiles (table was renamed from psychologist_profiles in 20260217095717).
--    This function is used by triggers and RLS; INSERT into public_locations was failing because
--    sync_marketplace_location() calls it and it referenced the old table name.
-- 2) Drop trigger sync_marketplace_locations on public_locations: it writes to public.marketplace_locations,
--    which was dropped in 20260217095717, so the trigger would fail after is_profile_public is fixed.

create or replace function public.is_profile_public(p_psychologist_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.public_profiles pp
    where pp.id = p_psychologist_id
      and pp.is_public = true
      and coalesce(pp.show_in_marketplace, true) = true
      and pp.display_name is not null
  );
$$;
comment on function public.is_profile_public(uuid) is
  'Returns true if the psychologist has a public profile (public_profiles) that is public and has display_name.';
drop trigger if exists sync_marketplace_locations on public.public_locations;
