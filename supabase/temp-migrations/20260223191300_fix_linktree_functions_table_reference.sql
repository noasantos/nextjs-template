-- migration-created-via: pnpm supabase:migration:new
-- Migration: fix_linktree_functions_table_reference
-- Created at: 2026-02-23T19:13:00Z
-- Purpose: Fix function enforce_linktree_active_limit to reference correct table name

-- Fix the enforce_linktree_active_limit function to use public_linktree_links instead of linktree_links
CREATE OR REPLACE FUNCTION public.enforce_linktree_active_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
DECLARE
  active_count integer;
BEGIN
  IF NEW.is_active IS TRUE THEN
    SELECT COUNT(*)
      INTO active_count
      FROM public.public_linktree_links
     WHERE psychologist_id = NEW.psychologist_id
       AND is_active = TRUE
       AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000');

    IF active_count >= 4 THEN
      RAISE EXCEPTION 'Maximum of 4 active links allowed'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- Recreate the trigger to ensure it's pointing to the right table
DROP TRIGGER IF EXISTS trg_enforce_linktree_active_limit ON public.public_linktree_links;
CREATE TRIGGER trg_enforce_linktree_active_limit
  BEFORE INSERT OR UPDATE OF is_active ON public.public_linktree_links
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_linktree_active_limit();

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.enforce_linktree_active_limit() TO authenticated;
GRANT EXECUTE ON FUNCTION public.enforce_linktree_active_limit() TO service_role;

COMMENT ON FUNCTION public.enforce_linktree_active_limit() IS 
'Enforces a maximum of 4 active links per psychologist. Fixed to reference public_linktree_links table.';
