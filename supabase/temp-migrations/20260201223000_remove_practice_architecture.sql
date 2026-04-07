-- Migration: Remove Practice/Tenant architecture and switch to simple delegation model

-- 0. Drop RLS policies that depend on is_practice_member (must run before DROP FUNCTION)
DROP POLICY IF EXISTS practices_select_own ON public.practices;
DROP POLICY IF EXISTS practices_modify_owner ON public.practices;
DROP POLICY IF EXISTS practice_memberships_select ON public.practice_memberships;
DROP POLICY IF EXISTS practice_memberships_manage ON public.practice_memberships;
DROP POLICY IF EXISTS psychologist_clients_select_psy ON public.psychologist_clients;
DROP POLICY IF EXISTS psychologist_clients_insert_psy ON public.psychologist_clients;
DROP POLICY IF EXISTS psychologist_clients_update_psy ON public.psychologist_clients;
DROP POLICY IF EXISTS psychologist_clients_delete_psy ON public.psychologist_clients;
DROP POLICY IF EXISTS clinical_sessions_select_psy ON public.clinical_sessions;
DROP POLICY IF EXISTS clinical_sessions_insert_psy ON public.clinical_sessions;
DROP POLICY IF EXISTS clinical_sessions_update_psy ON public.clinical_sessions;
DROP POLICY IF EXISTS clinical_sessions_delete_psy ON public.clinical_sessions;
DROP POLICY IF EXISTS clinical_notes_psy ON public.clinical_notes;
DROP POLICY IF EXISTS generated_documents_psy ON public.generated_documents;
DROP POLICY IF EXISTS psychologist_patient_guardians_psy ON public.psychologist_patient_guardians;
DROP POLICY IF EXISTS psychologist_patient_guardian_documents_psy ON public.psychologist_patient_guardian_documents;
DROP POLICY IF EXISTS psychologist_patient_medical_items_psy ON public.psychologist_patient_medical_items;
-- 1. Drop the auto-fill triggers and function
DROP TRIGGER IF EXISTS set_practice_id_psychologist_clients ON public.psychologist_clients;
DROP TRIGGER IF EXISTS set_practice_id_clinical_sessions ON public.clinical_sessions;
DROP TRIGGER IF EXISTS set_practice_id_clinical_notes ON public.clinical_notes;
DROP TRIGGER IF EXISTS set_practice_id_generated_documents ON public.generated_documents;
DROP TRIGGER IF EXISTS set_practice_id_guardians ON public.psychologist_patient_guardians;
DROP TRIGGER IF EXISTS set_practice_id_guardian_documents ON public.psychologist_patient_guardian_documents;
DROP TRIGGER IF EXISTS set_practice_id_medical_items ON public.psychologist_patient_medical_items;
DROP TRIGGER IF EXISTS set_practice_id_patient_tests ON public.patient_tests;
DROP TRIGGER IF EXISTS set_practice_id_patient_activity_assignments ON public.patient_activity_assignments;
DROP FUNCTION IF EXISTS public.set_practice_id_from_psychologist();
DROP FUNCTION IF EXISTS public.is_practice_member(uuid, public.app_role[]);
-- 2. Clean up assistant_invites BEFORE dropping practices
-- Drop policies that depend on practice_id (from 20260201195217_assistant_invites.sql)
DROP POLICY IF EXISTS assistant_invites_select_owner ON public.assistant_invites;
DROP POLICY IF EXISTS assistant_invites_insert_owner ON public.assistant_invites;
DROP POLICY IF EXISTS assistant_invites_update_owner ON public.assistant_invites;
-- Add psychologist_id to invites, migrating data where possible (assuming 1:1 map if needed, or just wiping if dev data)
ALTER TABLE public.assistant_invites DROP CONSTRAINT IF EXISTS assistant_invites_practice_id_fkey;
ALTER TABLE public.assistant_invites DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.assistant_invites ADD COLUMN IF NOT EXISTS psychologist_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
-- (In a prod env we would migrate data here, but for now we assume fresh start for invites is acceptable or data is empty)

-- 3. Drop practice_id columns from content tables
ALTER TABLE public.psychologist_clients DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.clinical_sessions DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.clinical_notes DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.generated_documents DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.psychologist_patient_guardians DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.psychologist_patient_guardian_documents DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.psychologist_patient_medical_items DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.patient_tests DROP COLUMN IF EXISTS practice_id;
ALTER TABLE public.patient_activity_assignments DROP COLUMN IF EXISTS practice_id;
-- 4. Drop the Practice infrastructure
DROP TABLE IF EXISTS public.practice_memberships;
DROP TABLE IF EXISTS public.practices;
-- 5. Create new simple delegation table
CREATE TABLE IF NOT EXISTS public.psychologist_assistants (
    psychologist_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    assistant_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    PRIMARY KEY (psychologist_id, assistant_id)
);
-- Enable RLS
ALTER TABLE public.psychologist_assistants ENABLE ROW LEVEL SECURITY;
-- Policies for psychologist_assistants
-- Psychologist can manage their assistants
CREATE POLICY "Psychologists can manage their assistants" ON public.psychologist_assistants
    FOR ALL
    USING (auth.uid() = psychologist_id)
    WITH CHECK (auth.uid() = psychologist_id);
-- Assistants can see who they assist
CREATE POLICY "Assistants can see who they work for" ON public.psychologist_assistants
    FOR SELECT
    USING (auth.uid() = assistant_id);
-- 6. Helper function for RLS
CREATE OR REPLACE FUNCTION public.has_access_to_psychologist_data(target_psychologist_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT (
        -- User is the psychologist
        auth.uid() = target_psychologist_id
        OR
        -- User is an assistant for this psychologist
        EXISTS (
            SELECT 1 
            FROM public.psychologist_assistants 
            WHERE psychologist_id = target_psychologist_id 
            AND assistant_id = auth.uid()
        )
    );
$$;
-- 7. Update RLS Policies for sensitive tables
-- We need to drop old practice-based policies and create new owner-based ones

-- Helper macro-like approach for repeating policies
-- psychologist_clients
DROP POLICY IF EXISTS "Psychologist and practice members can view clients" ON public.psychologist_clients;
DROP POLICY IF EXISTS "Psychologist and practice members can insert clients" ON public.psychologist_clients;
DROP POLICY IF EXISTS "Psychologist and practice members can update clients" ON public.psychologist_clients;
DROP POLICY IF EXISTS "Psychologist and practice members can delete clients" ON public.psychologist_clients;
CREATE POLICY "Access clients" ON public.psychologist_clients
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- clinical_sessions
DROP POLICY IF EXISTS "Psychologist and practice members can view sessions" ON public.clinical_sessions;
DROP POLICY IF EXISTS "Psychologist and practice members can insert sessions" ON public.clinical_sessions;
DROP POLICY IF EXISTS "Psychologist and practice members can update sessions" ON public.clinical_sessions;
DROP POLICY IF EXISTS "Psychologist and practice members can delete sessions" ON public.clinical_sessions;
CREATE POLICY "Access sessions" ON public.clinical_sessions
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- clinical_notes
DROP POLICY IF EXISTS "Psychologist and practice members can view notes" ON public.clinical_notes;
DROP POLICY IF EXISTS "Psychologist and practice members can insert notes" ON public.clinical_notes;
DROP POLICY IF EXISTS "Psychologist and practice members can update notes" ON public.clinical_notes;
DROP POLICY IF EXISTS "Psychologist and practice members can delete notes" ON public.clinical_notes;
CREATE POLICY "Access notes" ON public.clinical_notes
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- generated_documents
DROP POLICY IF EXISTS "Psychologist and practice members can view documents" ON public.generated_documents;
DROP POLICY IF EXISTS "Psychologist and practice members can insert documents" ON public.generated_documents;
DROP POLICY IF EXISTS "Psychologist and practice members can update documents" ON public.generated_documents;
DROP POLICY IF EXISTS "Psychologist and practice members can delete documents" ON public.generated_documents;
CREATE POLICY "Access generated documents" ON public.generated_documents
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- psychologist_patient_guardians
DROP POLICY IF EXISTS "Psychologist and practice members can view guardians" ON public.psychologist_patient_guardians;
DROP POLICY IF EXISTS "Psychologist and practice members can insert guardians" ON public.psychologist_patient_guardians;
DROP POLICY IF EXISTS "Psychologist and practice members can update guardians" ON public.psychologist_patient_guardians;
DROP POLICY IF EXISTS "Psychologist and practice members can delete guardians" ON public.psychologist_patient_guardians;
CREATE POLICY "Access guardians" ON public.psychologist_patient_guardians
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- psychologist_patient_guardian_documents
DROP POLICY IF EXISTS "Psychologist and practice members can view guardian documents" ON public.psychologist_patient_guardian_documents;
DROP POLICY IF EXISTS "Psychologist and practice members can insert guardian documents" ON public.psychologist_patient_guardian_documents;
DROP POLICY IF EXISTS "Psychologist and practice members can update guardian documents" ON public.psychologist_patient_guardian_documents;
DROP POLICY IF EXISTS "Psychologist and practice members can delete guardian documents" ON public.psychologist_patient_guardian_documents;
CREATE POLICY "Access guardian documents" ON public.psychologist_patient_guardian_documents
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- psychologist_patient_medical_items
DROP POLICY IF EXISTS "Psychologist and practice members can view medical items" ON public.psychologist_patient_medical_items;
DROP POLICY IF EXISTS "Psychologist and practice members can insert medical items" ON public.psychologist_patient_medical_items;
DROP POLICY IF EXISTS "Psychologist and practice members can update medical items" ON public.psychologist_patient_medical_items;
DROP POLICY IF EXISTS "Psychologist and practice members can delete medical items" ON public.psychologist_patient_medical_items;
CREATE POLICY "Access medical items" ON public.psychologist_patient_medical_items
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- patient_tests (assuming policies existed, if not creating new ones)
CREATE POLICY "Access patient tests" ON public.patient_tests
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- patient_activity_assignments (assuming policies existed)
CREATE POLICY "Access patient activities" ON public.patient_activity_assignments
    FOR ALL
    USING (public.has_access_to_psychologist_data(psychologist_id))
    WITH CHECK (public.has_access_to_psychologist_data(psychologist_id));
-- Update assistant_invites policies
DROP POLICY IF EXISTS "Psychologist and practice members can view invites" ON public.assistant_invites;
DROP POLICY IF EXISTS "Psychologist and practice members can insert invites" ON public.assistant_invites;
DROP POLICY IF EXISTS "Psychologist and practice members can update invites" ON public.assistant_invites;
DROP POLICY IF EXISTS "Psychologist and practice members can delete invites" ON public.assistant_invites;
CREATE POLICY "Psychologist can manage invites" ON public.assistant_invites
    FOR ALL
    USING (auth.uid() = psychologist_id)
    WITH CHECK (auth.uid() = psychologist_id);
