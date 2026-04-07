-- Migration: Fix Extension in Public Schema - pgaudit
-- Created at: 2026-02-20
-- Issue: Extension pgaudit installed in public schema creates security risks
-- Fix: Secure pgaudit functions and document migration path
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public

-- Create extensions schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS extensions;
-- Grant usage on extensions schema to public
GRANT USAGE ON SCHEMA extensions TO public;
-- Secure pgaudit functions by revoking access from non-superuser roles
-- We use a DO block to handle this dynamically
DO $$
DECLARE
  func_record RECORD;
  role_record RECORD;
BEGIN
  -- List of roles to revoke from (exclude superusers and postgres)
  FOR role_record IN 
    SELECT rolname 
    FROM pg_roles 
    WHERE rolname IN ('authenticated', 'anon', 'service_role')
  LOOP
    -- For each pgaudit function, revoke privileges
    FOR func_record IN 
      SELECT p.proname 
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE n.nspname = 'public' AND p.proname LIKE 'pgaudit%'
    LOOP
      BEGIN
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I() FROM %I', 
                       func_record.proname, role_record.rolname);
        RAISE NOTICE 'Revoked privileges on % from %', func_record.proname, role_record.rolname;
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not revoke from % on %: %', role_record.rolname, func_record.proname, SQLERRM;
      END;
    END LOOP;
  END LOOP;
END;
$$;
-- Document the extension location for future reference (only if extension exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_extension
    WHERE extname = 'pgaudit'
  ) THEN
    COMMENT ON EXTENSION pgaudit IS 'Audit extension installed in public schema.
To properly migrate to extensions schema, requires downtime to:
1. Drop event triggers pgaudit_ddl_command_end and pgaudit_sql_drop
2. DROP EXTENSION pgaudit
3. CREATE EXTENSION pgaudit WITH SCHEMA extensions
4. Re-create event triggers (done automatically by extension)

Current mitigation: Functions secured via explicit REVOKE on pgaudit functions.';
  END IF;
END;
$$;
-- Set default search path to include extensions schema
ALTER DATABASE postgres SET search_path TO "$user", public, extensions;
-- Verify pgaudit functions have proper security settings
DO $$
DECLARE
  func_record RECORD;
BEGIN
  FOR func_record IN 
    SELECT p.proname 
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname LIKE 'pgaudit%'
  LOOP
    BEGIN
      EXECUTE format('ALTER FUNCTION public.%I() SET search_path = pg_catalog, pg_temp', func_record.proname);
      RAISE NOTICE 'Secured function search_path: %', func_record.proname;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Could not set search_path for %: %', func_record.proname, SQLERRM;
    END;
  END LOOP;
END;
$$;
-- Create a function to properly migrate pgaudit when downtime is available
CREATE OR REPLACE FUNCTION extensions.migrate_pgaudit_to_extensions_schema()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_result text;
BEGIN
  -- This function provides a script for manual migration during maintenance window
  v_result := '
-- Pgaudit Migration Script (run during maintenance window):
-- 1. Stop all application connections
-- 2. Run:

-- Drop event triggers (they reference pgaudit functions)
DROP EVENT TRIGGER IF EXISTS pgaudit_ddl_command_end;
DROP EVENT TRIGGER IF EXISTS pgaudit_sql_drop;

-- Drop and recreate extension in extensions schema
DROP EXTENSION pgaudit;
CREATE EXTENSION pgaudit WITH SCHEMA extensions;

-- Event triggers are recreated automatically by the extension
-- 3. Restart applications
';
  RETURN v_result;
END;
$function$;
COMMENT ON FUNCTION extensions.migrate_pgaudit_to_extensions_schema() IS 
'Run SELECT extensions.migrate_pgaudit_to_extensions_schema() to get migration script';
