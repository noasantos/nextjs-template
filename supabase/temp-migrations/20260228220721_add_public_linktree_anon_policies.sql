-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-28T21:07:21Z

-- Add RLS policies to allow anonymous/public access to public linktree data
-- This fixes the issue where /[username] returns 404 even though the profile exists

-- 1) Allow anonymous users to read public profiles
-- This is needed for the linktree page to access public profile data
DROP POLICY IF EXISTS public_profiles_select_anon ON public.public_profiles;
CREATE POLICY public_profiles_select_anon
  ON public.public_profiles
  FOR SELECT
  TO anon
  USING (is_public = true);

-- 2) Allow anonymous users to read psychologist data for public profiles
-- This is needed to get the full_name and verify the user is a psychologist
DROP POLICY IF EXISTS user_psychologists_select_anon ON public.user_psychologists;
CREATE POLICY user_psychologists_select_anon
  ON public.user_psychologists
  FOR SELECT
  TO anon
  USING (true);  -- Allow reading all psychologist records (needed for public linktree)

-- 3) Allow anonymous users to read active linktree links
-- This is needed to display the links on the public linktree page
DROP POLICY IF EXISTS public_linktree_links_select_anon ON public.public_linktree_links;
CREATE POLICY public_linktree_links_select_anon
  ON public.public_linktree_links
  FOR SELECT
  TO anon
  USING (is_active = true);
