-- Migration: rename_client_columns_to_patient
-- Description: Rename psychologist_client_id columns to psychologist_patient_id

-------------------------------------------------------------------------------
-- 1. RENAME COLUMNS IN psychologist_clinical_sessions
-------------------------------------------------------------------------------
ALTER TABLE public.psychologist_clinical_sessions 
RENAME COLUMN psychologist_client_id TO psychologist_patient_id;
COMMENT ON COLUMN public.psychologist_clinical_sessions.psychologist_patient_id IS 'Reference to the psychologist_patients table (the patient record for this psychologist)';
-------------------------------------------------------------------------------
-- 2. RENAME COLUMNS IN psychologist_patient_charges
-------------------------------------------------------------------------------
ALTER TABLE public.psychologist_patient_charges 
RENAME COLUMN psychologist_client_id TO psychologist_patient_id;
COMMENT ON COLUMN public.psychologist_patient_charges.psychologist_patient_id IS 'Reference to the psychologist_patients table';
-------------------------------------------------------------------------------
-- 3. RENAME COLUMNS IN psychologist_patient_emergency_contacts
-------------------------------------------------------------------------------
ALTER TABLE public.psychologist_patient_emergency_contacts 
RENAME COLUMN psychologist_client_id TO psychologist_patient_id;
COMMENT ON COLUMN public.psychologist_patient_emergency_contacts.psychologist_patient_id IS 'Reference to the psychologist_patients table';
-------------------------------------------------------------------------------
-- 4. RENAME COLUMNS IN psychologist_patient_services
-------------------------------------------------------------------------------
ALTER TABLE public.psychologist_patient_services 
RENAME COLUMN psychologist_client_id TO psychologist_patient_id;
COMMENT ON COLUMN public.psychologist_patient_services.psychologist_patient_id IS 'Reference to the psychologist_patients table';
-------------------------------------------------------------------------------
-- 5. RENAME COLUMNS IN public_client_checkout_intents
-------------------------------------------------------------------------------
ALTER TABLE public.public_client_checkout_intents 
RENAME COLUMN psychologist_client_id TO psychologist_patient_id;
COMMENT ON COLUMN public.public_client_checkout_intents.psychologist_patient_id IS 'Reference to the psychologist_patients table';
-------------------------------------------------------------------------------
-- 6. RENAME therapist_client_id TO psychologist_patient_id IN psychologist_patient_medical_items
-------------------------------------------------------------------------------
ALTER TABLE public.psychologist_patient_medical_items 
RENAME COLUMN therapist_client_id TO psychologist_patient_id;
COMMENT ON COLUMN public.psychologist_patient_medical_items.psychologist_patient_id IS 'Reference to the psychologist_patients table';
-------------------------------------------------------------------------------
-- 7. UPDATE FOREIGN KEY CONSTRAINT NAMES (for documentation purposes)
-------------------------------------------------------------------------------
-- Note: PostgreSQL automatically updates FK constraints when columns are renamed
-- but we document them here for clarity

-- clinical_sessions_psychologist_client_id_fkey -> clinical_sessions_psychologist_patient_id_fkey
-- psychologist_client_charges_psychologist_client_id_fkey -> psychologist_patient_charges_psychologist_patient_id_fkey
-- patient_emergency_contacts_psychologist_client_id_fkey -> patient_emergency_contacts_psychologist_patient_id_fkey
-- psychologist_client_services_psychologist_client_id_fkey -> psychologist_patient_services_psychologist_patient_id_fkey
-- marketplace_payment_intents_psychologist_client_id_fkey -> public_client_checkout_intents_psychologist_patient_id_fkey

-------------------------------------------------------------------------------
-- 8. UPDATE RPC FUNCTION ARGUMENTS
-------------------------------------------------------------------------------
-- Check if the function get_patient_charges exists and update its arguments
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p 
             JOIN pg_namespace n ON p.pronamespace = n.oid 
             WHERE n.nspname = 'public' AND p.proname = 'get_patient_charges') THEN
    RAISE NOTICE 'Function get_patient_charges may need argument updates';
  END IF;
END $$;
-- Note: Functions that reference psychologist_client_id in their implementation
-- will need to be updated. The types will be regenerated after this migration.

-------------------------------------------------------------------------------
-- 9. TABLE DESCRIPTIONS
-------------------------------------------------------------------------------

COMMENT ON TABLE public.psychologist_patients IS 'Psychologist-specific patient records. Links a global user_patients record to a specific psychologist with custom fields like manual vs synced data, pricing, and relationship metadata.';
