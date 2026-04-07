-- Rename preferred_name to display_name across remaining tables
-- This migration handles patients, psychologist_profiles and marketplace_psychologist_profiles (patient field)

BEGIN;
-- 1. Table: public.patients
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patients' AND column_name = 'preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'patients' AND column_name = 'display_name') THEN
      ALTER TABLE public.patients RENAME COLUMN preferred_name TO display_name;
    ELSE
      -- If display_name already exists, we might want to merge or just drop the old one if it's redundant
      -- For safety, we just drop the old one if the new one exists
      ALTER TABLE public.patients DROP COLUMN preferred_name;
    END IF;
  END IF;
END $$;
-- 2. Table: public.psychologist_profiles
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'psychologist_profiles' AND column_name = 'preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'psychologist_profiles' AND column_name = 'display_name') THEN
      ALTER TABLE public.psychologist_profiles RENAME COLUMN preferred_name TO display_name;
    ELSE
      ALTER TABLE public.psychologist_profiles DROP COLUMN preferred_name;
    END IF;
  END IF;
END $$;
-- 3. Table: public.marketplace_psychologist_profiles (patient_preferred_name -> patient_display_name)
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'marketplace_psychologist_profiles' AND column_name = 'patient_preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'marketplace_psychologist_profiles' AND column_name = 'patient_display_name') THEN
      ALTER TABLE public.marketplace_psychologist_profiles RENAME COLUMN patient_preferred_name TO patient_display_name;
    ELSE
      ALTER TABLE public.marketplace_psychologist_profiles DROP COLUMN patient_preferred_name;
    END IF;
  END IF;
END $$;
COMMIT;
