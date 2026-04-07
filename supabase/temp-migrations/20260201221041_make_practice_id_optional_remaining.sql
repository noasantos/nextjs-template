-- Migration: Make practice_id optional for remaining tables and add auto-fill triggers
-- Tables: patient_tests, patient_activity_assignments (only if practice_id column exists)

-- 1. Make practice_id optional (DEFAULT NULL) only where the column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'patient_tests' AND column_name = 'practice_id'
  ) THEN
    ALTER TABLE public.patient_tests ALTER COLUMN practice_id SET DEFAULT NULL;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'patient_activity_assignments' AND column_name = 'practice_id'
  ) THEN
    ALTER TABLE public.patient_activity_assignments ALTER COLUMN practice_id SET DEFAULT NULL;
  END IF;
END $$;
-- 2. Add triggers to auto-fill practice_id from psychologist_id only if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'patient_tests' AND column_name = 'practice_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_patient_tests'
  ) THEN
    CREATE TRIGGER set_practice_id_patient_tests
    BEFORE INSERT OR UPDATE ON public.patient_tests
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'patient_activity_assignments' AND column_name = 'practice_id'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_patient_activity_assignments'
  ) THEN
    CREATE TRIGGER set_practice_id_patient_activity_assignments
    BEFORE INSERT OR UPDATE ON public.patient_activity_assignments
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;
END $$;
