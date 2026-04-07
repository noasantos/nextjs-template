-- Practices (tenant root) and memberships
CREATE TABLE IF NOT EXISTS public.practices (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.practice_memberships (
  practice_id uuid NOT NULL REFERENCES public.practices(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (practice_id, user_id)
);
CREATE INDEX IF NOT EXISTS practice_memberships_user_idx ON public.practice_memberships (user_id, practice_id);
CREATE INDEX IF NOT EXISTS practice_memberships_role_idx ON public.practice_memberships (role);
-- Backfill practices + memberships (1:1 for existing psychologists)
INSERT INTO public.practices (id, owner_id, name)
SELECT p.id, p.id, p.full_name
FROM public.psychologists p
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.practice_memberships (practice_id, user_id, role)
SELECT p.id, p.id, 'psychologist'::public.app_role
FROM public.psychologists p
ON CONFLICT (practice_id, user_id) DO NOTHING;
-- Backfill patient membership from psychologist_clients
INSERT INTO public.practice_memberships (practice_id, user_id, role)
SELECT DISTINCT pc.psychologist_id, pc.patient_id, 'patient'::public.app_role
FROM public.psychologist_clients pc
WHERE pc.patient_id IS NOT NULL
ON CONFLICT (practice_id, user_id) DO NOTHING;
-- Add practice_id to sensitive tables (backfill from psychologist_id)
ALTER TABLE public.psychologist_clients
  ADD COLUMN IF NOT EXISTS practice_id uuid;
UPDATE public.psychologist_clients
SET practice_id = psychologist_id
WHERE practice_id IS NULL;
ALTER TABLE public.psychologist_clients
  ADD CONSTRAINT psychologist_clients_practice_id_fkey
  FOREIGN KEY (practice_id) REFERENCES public.practices(id) ON DELETE CASCADE;
ALTER TABLE public.psychologist_clients
  ALTER COLUMN practice_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS psychologist_clients_practice_id_idx ON public.psychologist_clients (practice_id);
ALTER TABLE public.clinical_sessions
  ADD COLUMN IF NOT EXISTS practice_id uuid;
UPDATE public.clinical_sessions
SET practice_id = psychologist_id
WHERE practice_id IS NULL;
ALTER TABLE public.clinical_sessions
  ADD CONSTRAINT clinical_sessions_practice_id_fkey
  FOREIGN KEY (practice_id) REFERENCES public.practices(id) ON DELETE CASCADE;
ALTER TABLE public.clinical_sessions
  ALTER COLUMN practice_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS clinical_sessions_practice_id_idx ON public.clinical_sessions (practice_id);
ALTER TABLE public.clinical_notes
  ADD COLUMN IF NOT EXISTS practice_id uuid;
UPDATE public.clinical_notes
SET practice_id = psychologist_id
WHERE practice_id IS NULL;
ALTER TABLE public.clinical_notes
  ADD CONSTRAINT clinical_notes_practice_id_fkey
  FOREIGN KEY (practice_id) REFERENCES public.practices(id) ON DELETE CASCADE;
ALTER TABLE public.clinical_notes
  ALTER COLUMN practice_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS clinical_notes_practice_id_idx ON public.clinical_notes (practice_id);
ALTER TABLE public.generated_documents
  ADD COLUMN IF NOT EXISTS practice_id uuid;
UPDATE public.generated_documents
SET practice_id = psychologist_id
WHERE practice_id IS NULL;
ALTER TABLE public.generated_documents
  ADD CONSTRAINT generated_documents_practice_id_fkey
  FOREIGN KEY (practice_id) REFERENCES public.practices(id) ON DELETE CASCADE;
ALTER TABLE public.generated_documents
  ALTER COLUMN practice_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS generated_documents_practice_id_idx ON public.generated_documents (practice_id);
ALTER TABLE public.psychologist_patient_guardians
  ADD COLUMN IF NOT EXISTS practice_id uuid;
UPDATE public.psychologist_patient_guardians
SET practice_id = psychologist_id
WHERE practice_id IS NULL;
ALTER TABLE public.psychologist_patient_guardians
  ADD CONSTRAINT psychologist_patient_guardians_practice_id_fkey
  FOREIGN KEY (practice_id) REFERENCES public.practices(id) ON DELETE CASCADE;
ALTER TABLE public.psychologist_patient_guardians
  ALTER COLUMN practice_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS psychologist_patient_guardians_practice_id_idx ON public.psychologist_patient_guardians (practice_id);
ALTER TABLE public.psychologist_patient_guardian_documents
  ADD COLUMN IF NOT EXISTS practice_id uuid;
UPDATE public.psychologist_patient_guardian_documents
SET practice_id = psychologist_id
WHERE practice_id IS NULL;
ALTER TABLE public.psychologist_patient_guardian_documents
  ADD CONSTRAINT psychologist_patient_guardian_documents_practice_id_fkey
  FOREIGN KEY (practice_id) REFERENCES public.practices(id) ON DELETE CASCADE;
ALTER TABLE public.psychologist_patient_guardian_documents
  ALTER COLUMN practice_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS psychologist_patient_guardian_documents_practice_id_idx ON public.psychologist_patient_guardian_documents (practice_id);
ALTER TABLE public.psychologist_patient_medical_items
  ADD COLUMN IF NOT EXISTS practice_id uuid;
UPDATE public.psychologist_patient_medical_items
SET practice_id = psychologist_id
WHERE practice_id IS NULL;
ALTER TABLE public.psychologist_patient_medical_items
  ADD CONSTRAINT psychologist_patient_medical_items_practice_id_fkey
  FOREIGN KEY (practice_id) REFERENCES public.practices(id) ON DELETE CASCADE;
ALTER TABLE public.psychologist_patient_medical_items
  ALTER COLUMN practice_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS psychologist_patient_medical_items_practice_id_idx ON public.psychologist_patient_medical_items (practice_id);
-- Ensure practice_id is auto-set for legacy writes
CREATE OR REPLACE FUNCTION public.set_practice_id_from_psychologist()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.practice_id IS NULL THEN
    NEW.practice_id := NEW.psychologist_id;
  END IF;
  RETURN NEW;
END;
$$;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_psychologist_clients'
  ) THEN
    CREATE TRIGGER set_practice_id_psychologist_clients
    BEFORE INSERT OR UPDATE ON public.psychologist_clients
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_clinical_sessions'
  ) THEN
    CREATE TRIGGER set_practice_id_clinical_sessions
    BEFORE INSERT OR UPDATE ON public.clinical_sessions
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_clinical_notes'
  ) THEN
    CREATE TRIGGER set_practice_id_clinical_notes
    BEFORE INSERT OR UPDATE ON public.clinical_notes
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_generated_documents'
  ) THEN
    CREATE TRIGGER set_practice_id_generated_documents
    BEFORE INSERT OR UPDATE ON public.generated_documents
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_guardians'
  ) THEN
    CREATE TRIGGER set_practice_id_guardians
    BEFORE INSERT OR UPDATE ON public.psychologist_patient_guardians
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_guardian_documents'
  ) THEN
    CREATE TRIGGER set_practice_id_guardian_documents
    BEFORE INSERT OR UPDATE ON public.psychologist_patient_guardian_documents
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_practice_id_medical_items'
  ) THEN
    CREATE TRIGGER set_practice_id_medical_items
    BEFORE INSERT OR UPDATE ON public.psychologist_patient_medical_items
    FOR EACH ROW EXECUTE FUNCTION public.set_practice_id_from_psychologist();
  END IF;
END $$;
