-- Migration: rename_core_identity_tables_to_user_prefix
-- Target Tables: admins, assistants, patients, psychologists

-------------------------------------------------------------------------------
-- 1. RENAME CORE IDENTITY TABLES
-------------------------------------------------------------------------------

-- Rename admins to user_admins
ALTER TABLE IF EXISTS public.admins RENAME TO user_admins;
-- Rename assistants to user_assistants
ALTER TABLE IF EXISTS public.assistants RENAME TO user_assistants;
-- Rename patients to user_patients
ALTER TABLE IF EXISTS public.patients RENAME TO user_patients;
-- Rename psychologists to user_psychologists
ALTER TABLE IF EXISTS public.psychologists RENAME TO user_psychologists;
-------------------------------------------------------------------------------
-- 2. TABLE DESCRIPTIONS (English)
-------------------------------------------------------------------------------

COMMENT ON TABLE public.user_admins IS 'Core identity table for internal platform administrators. Extends auth.users.';
COMMENT ON TABLE public.user_assistants IS 'Core identity table for clinic assistants and secretaries. Extends auth.users.';
COMMENT ON TABLE public.user_patients IS 'Core identity table for patients (global profile). Extends auth.users.';
COMMENT ON TABLE public.user_psychologists IS 'Core identity table for psychologists (the primary platform users). Extends auth.users.';
