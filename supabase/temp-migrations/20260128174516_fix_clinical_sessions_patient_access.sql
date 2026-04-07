-- Fix patient access to clinical sessions
-- Patients should be able to view their own sessions where they are the client.

-- 1. clinical_sessions
DROP POLICY IF EXISTS "clinical_sessions_owner_access" ON public.clinical_sessions;
DROP POLICY IF EXISTS "clinical_sessions_select" ON public.clinical_sessions;
DROP POLICY IF EXISTS "clinical_sessions_insert" ON public.clinical_sessions;
DROP POLICY IF EXISTS "clinical_sessions_update" ON public.clinical_sessions;
DROP POLICY IF EXISTS "clinical_sessions_delete" ON public.clinical_sessions;
-- Combined SELECT policy for psychologists and patients
CREATE POLICY "clinical_sessions_select" ON public.clinical_sessions
  FOR SELECT TO authenticated
  USING (
    is_admin() OR 
    (SELECT auth.uid()) = psychologist_id OR 
    EXISTS (
      SELECT 1 FROM public.psychologist_clients pc 
      WHERE pc.id = psychologist_client_id AND pc.patient_id = (SELECT auth.uid())
    )
  );
-- Specific insert policy
CREATE POLICY "clinical_sessions_insert" ON public.clinical_sessions
  FOR INSERT TO authenticated
  WITH CHECK (is_admin() OR (SELECT auth.uid()) = psychologist_id);
-- Combined UPDATE policy for psychologists and patients (to allow cancellation)
CREATE POLICY "clinical_sessions_update" ON public.clinical_sessions
  FOR UPDATE TO authenticated
  USING (
    is_admin() OR 
    (SELECT auth.uid()) = psychologist_id OR 
    EXISTS (
      SELECT 1 FROM public.psychologist_clients pc 
      WHERE pc.id = psychologist_client_id AND pc.patient_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    is_admin() OR 
    (SELECT auth.uid()) = psychologist_id OR 
    EXISTS (
      SELECT 1 FROM public.psychologist_clients pc 
      WHERE pc.id = psychologist_client_id AND pc.patient_id = (SELECT auth.uid())
    )
  );
CREATE POLICY "clinical_sessions_delete" ON public.clinical_sessions
  FOR DELETE TO authenticated
  USING (is_admin() OR (SELECT auth.uid()) = psychologist_id);
