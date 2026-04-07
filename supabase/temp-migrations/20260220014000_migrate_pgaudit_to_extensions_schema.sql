-- Migration: Migrate pgaudit extension from public to extensions schema
-- Created at: 2026-02-20
-- WARNING: Execute only during maintenance window!
-- Issue: Extension pgaudit in public schema (security warning)
-- Fix: Migrate to extensions schema
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public

-- Step 1: Ensure extensions schema exists
CREATE SCHEMA IF NOT EXISTS extensions;
-- Step 2: Drop event triggers (they reference pgaudit functions)
DO $$
BEGIN
  BEGIN
    DROP EVENT TRIGGER IF EXISTS pgaudit_ddl_command_end;
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping DROP EVENT TRIGGER pgaudit_ddl_command_end (insufficient_privilege)';
  END;

  BEGIN
    DROP EVENT TRIGGER IF EXISTS pgaudit_sql_drop;
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping DROP EVENT TRIGGER pgaudit_sql_drop (insufficient_privilege)';
  END;
END;
$$;
-- Step 3: Drop extension from public schema
DO $$
BEGIN
  BEGIN
    DROP EXTENSION IF EXISTS pgaudit;
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping DROP EXTENSION pgaudit (insufficient_privilege)';
  END;
END;
$$;
-- Step 4: Create extension in extensions schema
DO $$
BEGIN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS pgaudit WITH SCHEMA extensions;
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'Skipping CREATE EXTENSION pgaudit (insufficient_privilege)';
  END;
END;
$$;
-- Step 5: Update search_path to include extensions
ALTER DATABASE postgres SET search_path TO "$user", public, extensions;
-- Step 6: Update comment
COMMENT ON EXTENSION pgaudit IS 'Audit extension migrated to extensions schema. 
Event triggers pgaudit_ddl_command_end and pgaudit_sql_drop are automatically recreated by the extension.';
-- Step 7: Revoke privileges on pgaudit functions from non-superuser roles
DO $$
DECLARE
  func_record RECORD;
  role_record RECORD;
BEGIN
  FOR role_record IN 
    SELECT rolname FROM pg_roles WHERE rolname IN ('authenticated', 'anon', 'service_role')
  LOOP
    FOR func_record IN 
      SELECT p.proname 
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE n.nspname = 'extensions' AND p.proname LIKE 'pgaudit%'
    LOOP
      BEGIN
        EXECUTE format('REVOKE ALL ON FUNCTION extensions.%I() FROM %I', 
                       func_record.proname, role_record.rolname);
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not revoke from % on %: %', role_record.rolname, func_record.proname, SQLERRM;
      END;
    END LOOP;
  END LOOP;
END;
$$;
