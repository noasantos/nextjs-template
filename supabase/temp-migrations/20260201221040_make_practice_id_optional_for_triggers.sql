-- Migration: Make practice_id columns optional (with DEFAULT NULL)
-- These columns are automatically populated by triggers, so they shouldn't be
-- required in INSERT statements. Making them DEFAULT NULL allows the types
-- system to recognize them as optional.

-- psychologist_clients
ALTER TABLE public.psychologist_clients 
  ALTER COLUMN practice_id SET DEFAULT NULL;
-- clinical_sessions  
ALTER TABLE public.clinical_sessions 
  ALTER COLUMN practice_id SET DEFAULT NULL;
-- clinical_notes
ALTER TABLE public.clinical_notes 
  ALTER COLUMN practice_id SET DEFAULT NULL;
-- generated_documents
ALTER TABLE public.generated_documents 
  ALTER COLUMN practice_id SET DEFAULT NULL;
-- psychologist_patient_guardians
ALTER TABLE public.psychologist_patient_guardians 
  ALTER COLUMN practice_id SET DEFAULT NULL;
-- psychologist_patient_guardian_documents
ALTER TABLE public.psychologist_patient_guardian_documents 
  ALTER COLUMN practice_id SET DEFAULT NULL;
-- psychologist_patient_medical_items
ALTER TABLE public.psychologist_patient_medical_items 
  ALTER COLUMN practice_id SET DEFAULT NULL;
