-- migration-created-via: pnpm supabase:migration:new
-- Remove obsolete marketplace sync functions and triggers
-- Tables marketplace_psychologist_profiles, marketplace_linktree_links, marketplace_locations
-- were dropped in 20260217095717_add_table_descriptions_and_refinements.sql (unified into public_* tables)
-- But functions in later migrations still reference them, causing "relation does not exist" errors.

-- =============================================================================
-- 1. DROP TRIGGERS (must be done before dropping functions)
-- =============================================================================

-- Drop trigger on public_profiles that calls sync_marketplace_profile()
DROP TRIGGER IF EXISTS sync_marketplace_profile ON public.public_profiles;

-- Drop trigger on public_linktree_links that calls sync_marketplace_linktree_link()
DROP TRIGGER IF EXISTS sync_marketplace_linktree_links ON public.public_linktree_links;

-- Drop trigger on public_locations that calls sync_marketplace_location()
DROP TRIGGER IF EXISTS sync_marketplace_locations ON public.public_locations;

-- =============================================================================
-- 2. REPLACE OBSOLETE FUNCTIONS WITH NO-OP VERSIONS
-- =============================================================================

-- sync_marketplace_profile: Now a no-op since there's no more separate marketplace table
-- The public_profiles table IS the marketplace profile now
CREATE OR REPLACE FUNCTION public.sync_marketplace_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  -- No-op: Tables marketplace_* were removed and unified into public_*
  -- Data is now maintained directly in public_profiles, no sync needed
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

-- sync_marketplace_linktree_link: Now a no-op
CREATE OR REPLACE FUNCTION public.sync_marketplace_linktree_link()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  -- No-op: Tables marketplace_* were removed and unified into public_*
  -- Data is now maintained directly in public_linktree_links, no sync needed
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

-- sync_marketplace_location: Now a no-op
CREATE OR REPLACE FUNCTION public.sync_marketplace_location()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  -- No-op: Tables marketplace_* were removed and unified into public_*
  -- Data is now maintained directly in public_locations, no sync needed
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$function$;

-- =============================================================================
-- 3. RE-CREATE TRIGGERS AS NO-OP (for backward compatibility)
-- =============================================================================

-- Re-create trigger on public_profiles (no-op function)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'sync_marketplace_profile' 
    AND tgrelid = 'public.public_profiles'::regclass
  ) THEN
    CREATE TRIGGER sync_marketplace_profile
    AFTER INSERT OR UPDATE OR DELETE ON public.public_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_marketplace_profile();
  END IF;
END;
$$;

-- Re-create trigger on public_linktree_links (no-op function)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'sync_marketplace_linktree_links' 
    AND tgrelid = 'public.public_linktree_links'::regclass
  ) THEN
    CREATE TRIGGER sync_marketplace_linktree_links
    AFTER INSERT OR UPDATE OR DELETE ON public.public_linktree_links
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_marketplace_linktree_link();
  END IF;
END;
$$;

-- Re-create trigger on public_locations (no-op function)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'sync_marketplace_locations' 
    AND tgrelid = 'public.public_locations'::regclass
  ) THEN
    CREATE TRIGGER sync_marketplace_locations
    AFTER INSERT OR UPDATE OR DELETE ON public.public_locations
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_marketplace_location();
  END IF;
END;
$$;
