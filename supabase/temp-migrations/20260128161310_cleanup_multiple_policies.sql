-- Consolidation of Multiple Permissive Policies

-- 1. psychologist_clients
-- Consolidating SELECT access for both psychologists and patients
DROP POLICY IF EXISTS "Psychologists can manage their clients" ON public.psychologist_clients;
DROP POLICY IF EXISTS "Patients can view their own client record" ON public.psychologist_clients;
CREATE POLICY "psychologist_clients_owner_access" ON public.psychologist_clients
  FOR ALL TO authenticated 
  USING ((SELECT auth.uid()) = psychologist_id);
CREATE POLICY "psychologist_clients_patient_select" ON public.psychologist_clients
  FOR SELECT TO authenticated 
  USING ((SELECT auth.uid()) = patient_id);
-- Note: The performance advisor complains because there are two SELECT policies.
-- Let's consolidate into ONE SELECT policy and separate ALL for others.
DROP POLICY IF EXISTS "psychologist_clients_owner_access" ON public.psychologist_clients;
DROP POLICY IF EXISTS "psychologist_clients_patient_select" ON public.psychologist_clients;
CREATE POLICY "psychologist_clients_select" ON public.psychologist_clients
  FOR SELECT TO authenticated 
  USING ((SELECT auth.uid()) = psychologist_id OR (SELECT auth.uid()) = patient_id);
CREATE POLICY "psychologist_clients_manage" ON public.psychologist_clients
  FOR ALL TO authenticated 
  USING ((SELECT auth.uid()) = psychologist_id)
  WITH CHECK ((SELECT auth.uid()) = psychologist_id);
-- 2. session_reschedule_requests
DROP POLICY IF EXISTS "reschedule_requests_owner_access" ON public.session_reschedule_requests;
DROP POLICY IF EXISTS "reschedule_requests_select_v2" ON public.session_reschedule_requests;
CREATE POLICY "session_reschedule_requests_select" ON public.session_reschedule_requests
  FOR SELECT TO authenticated 
  USING (
    is_admin() OR 
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s 
        WHERE s.id = session_id AND (
            s.psychologist_id = (SELECT auth.uid()) OR 
            EXISTS (
                SELECT 1 FROM public.psychologist_clients pc 
                WHERE pc.id = s.psychologist_client_id AND pc.patient_id = (SELECT auth.uid())
            )
        )
    )
  );
CREATE POLICY "session_reschedule_requests_manage" ON public.session_reschedule_requests
  FOR ALL TO authenticated 
  USING (
    is_admin() OR 
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s 
        WHERE s.id = session_id AND s.psychologist_id = (SELECT auth.uid())
    )
  );
-- 3. user_roles
DROP POLICY IF EXISTS "Admins can manage user roles" ON public.user_roles;
DROP POLICY IF EXISTS "Users can view own roles" ON public.user_roles;
CREATE POLICY "user_roles_select" ON public.user_roles
  FOR SELECT TO authenticated 
  USING (is_admin() OR (SELECT auth.uid()) = user_id);
CREATE POLICY "user_roles_manage" ON public.user_roles
  FOR ALL TO authenticated 
  USING (is_admin())
  WITH CHECK (is_admin());
