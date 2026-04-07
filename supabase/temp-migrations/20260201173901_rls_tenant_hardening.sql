-- RLS hardening for tenant isolation and role separation

-- Helper: practice membership check
CREATE OR REPLACE FUNCTION public.is_practice_member(p_practice_id uuid, p_roles public.app_role[] DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.practice_memberships pm
    WHERE pm.practice_id = p_practice_id
      AND pm.user_id = (SELECT auth.uid())
      AND (p_roles IS NULL OR pm.role = ANY (p_roles))
  );
$$;
-- Practices RLS
ALTER TABLE public.practices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practice_memberships ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS practices_select_own ON public.practices;
CREATE POLICY practices_select_own
ON public.practices
FOR SELECT
TO authenticated
USING (is_admin() OR owner_id = (SELECT auth.uid()) OR is_practice_member(id, ARRAY['psychologist','assistant','patient']::public.app_role[]));
DROP POLICY IF EXISTS practices_modify_owner ON public.practices;
CREATE POLICY practices_modify_owner
ON public.practices
FOR UPDATE
TO authenticated
USING (is_admin() OR owner_id = (SELECT auth.uid()))
WITH CHECK (is_admin() OR owner_id = (SELECT auth.uid()));
DROP POLICY IF EXISTS practice_memberships_select ON public.practice_memberships;
CREATE POLICY practice_memberships_select
ON public.practice_memberships
FOR SELECT
TO authenticated
USING (is_admin() OR user_id = (SELECT auth.uid()) OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
DROP POLICY IF EXISTS practice_memberships_manage ON public.practice_memberships;
CREATE POLICY practice_memberships_manage
ON public.practice_memberships
FOR ALL
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]))
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
-- Sensitive tables: psychologist/admin only (assistant and patient denied)
-- psychologist_clients
DROP POLICY IF EXISTS psychologist_clients_select ON public.psychologist_clients;
DROP POLICY IF EXISTS psychologist_clients_insert ON public.psychologist_clients;
DROP POLICY IF EXISTS psychologist_clients_update ON public.psychologist_clients;
DROP POLICY IF EXISTS psychologist_clients_delete ON public.psychologist_clients;
CREATE POLICY psychologist_clients_select_psy
ON public.psychologist_clients
FOR SELECT
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
CREATE POLICY psychologist_clients_insert_psy
ON public.psychologist_clients
FOR INSERT
TO authenticated
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
CREATE POLICY psychologist_clients_update_psy
ON public.psychologist_clients
FOR UPDATE
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]))
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
CREATE POLICY psychologist_clients_delete_psy
ON public.psychologist_clients
FOR DELETE
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
-- clinical_sessions
DROP POLICY IF EXISTS clinical_sessions_select ON public.clinical_sessions;
DROP POLICY IF EXISTS clinical_sessions_insert ON public.clinical_sessions;
DROP POLICY IF EXISTS clinical_sessions_update ON public.clinical_sessions;
DROP POLICY IF EXISTS clinical_sessions_delete ON public.clinical_sessions;
DROP POLICY IF EXISTS clinical_sessions_owner_access ON public.clinical_sessions;
CREATE POLICY clinical_sessions_select_psy
ON public.clinical_sessions
FOR SELECT
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
CREATE POLICY clinical_sessions_insert_psy
ON public.clinical_sessions
FOR INSERT
TO authenticated
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
CREATE POLICY clinical_sessions_update_psy
ON public.clinical_sessions
FOR UPDATE
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]))
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
CREATE POLICY clinical_sessions_delete_psy
ON public.clinical_sessions
FOR DELETE
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
-- clinical_notes
DROP POLICY IF EXISTS clinical_notes_owner_access ON public.clinical_notes;
CREATE POLICY clinical_notes_psy
ON public.clinical_notes
FOR ALL
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]))
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
-- generated_documents
DROP POLICY IF EXISTS generated_documents_owner_access ON public.generated_documents;
CREATE POLICY generated_documents_psy
ON public.generated_documents
FOR ALL
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]))
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
-- psychologist_patient_guardians
DROP POLICY IF EXISTS "Psychologists can manage patient guardians" ON public.psychologist_patient_guardians;
CREATE POLICY psychologist_patient_guardians_psy
ON public.psychologist_patient_guardians
FOR ALL
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]))
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
-- psychologist_patient_guardian_documents
DROP POLICY IF EXISTS "Psychologists can manage patient guardian documents" ON public.psychologist_patient_guardian_documents;
CREATE POLICY psychologist_patient_guardian_documents_psy
ON public.psychologist_patient_guardian_documents
FOR ALL
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]))
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
-- psychologist_patient_medical_items
DROP POLICY IF EXISTS "Psychologists can manage patient medical items" ON public.psychologist_patient_medical_items;
CREATE POLICY psychologist_patient_medical_items_psy
ON public.psychologist_patient_medical_items
FOR ALL
TO authenticated
USING (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]))
WITH CHECK (is_admin() OR is_practice_member(practice_id, ARRAY['psychologist']::public.app_role[]));
-- psychologist_profiles: remove public select; keep own/admin
DROP POLICY IF EXISTS psychologist_profiles_select_public_or_own ON public.psychologist_profiles;
CREATE POLICY psychologist_profiles_select_own
ON public.psychologist_profiles
FOR SELECT
TO authenticated
USING (is_admin() OR id = (SELECT auth.uid()));
