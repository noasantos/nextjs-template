-- Final RLS Performance Cleanup: Splitting ALL policies into specific actions
-- Goal: Ensure only ONE policy applies per (role, action) to avoid multiple evaluations.

-- 1. psychologist_clients
DROP POLICY IF EXISTS "psychologist_clients_manage" ON public.psychologist_clients;
DROP POLICY IF EXISTS "psychologist_clients_select" ON public.psychologist_clients;
-- Single SELECT policy for everyone
CREATE POLICY "psychologist_clients_select" ON public.psychologist_clients
  FOR SELECT TO authenticated 
  USING ((SELECT auth.uid()) = psychologist_id OR (SELECT auth.uid()) = patient_id);
-- Specific write policies for the psychologist
CREATE POLICY "psychologist_clients_insert" ON public.psychologist_clients
  FOR INSERT TO authenticated 
  WITH CHECK ((SELECT auth.uid()) = psychologist_id);
CREATE POLICY "psychologist_clients_update" ON public.psychologist_clients
  FOR UPDATE TO authenticated 
  USING ((SELECT auth.uid()) = psychologist_id)
  WITH CHECK ((SELECT auth.uid()) = psychologist_id);
CREATE POLICY "psychologist_clients_delete" ON public.psychologist_clients
  FOR DELETE TO authenticated 
  USING ((SELECT auth.uid()) = psychologist_id);
-- 2. session_reschedule_requests
DROP POLICY IF EXISTS "session_reschedule_requests_manage" ON public.session_reschedule_requests;
DROP POLICY IF EXISTS "session_reschedule_requests_select" ON public.session_reschedule_requests;
-- Single SELECT policy
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
-- Specific write policies
CREATE POLICY "session_reschedule_requests_write" ON public.session_reschedule_requests
  FOR ALL TO authenticated 
  USING (
    is_admin() OR 
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s 
        WHERE s.id = session_id AND s.psychologist_id = (SELECT auth.uid())
    )
  );
-- NOTE: We keep 'FOR ALL' here but since we changed the name and logic, 
-- we need to be careful. Actually, to be 100% compliant with the lint, 
-- let's use INSERT, UPDATE, DELETE specifically and NOT 'ALL' 
-- if a SELECT policy already exists.

DROP POLICY IF EXISTS "session_reschedule_requests_write" ON public.session_reschedule_requests;
CREATE POLICY "session_reschedule_requests_insert" ON public.session_reschedule_requests
  FOR INSERT TO authenticated 
  WITH CHECK (
    is_admin() OR 
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s 
        WHERE s.id = session_id AND s.psychologist_id = (SELECT auth.uid())
    )
  );
CREATE POLICY "session_reschedule_requests_update" ON public.session_reschedule_requests
  FOR UPDATE TO authenticated 
  USING (
    is_admin() OR 
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s 
        WHERE s.id = session_id AND s.psychologist_id = (SELECT auth.uid())
    )
  );
CREATE POLICY "session_reschedule_requests_delete" ON public.session_reschedule_requests
  FOR DELETE TO authenticated 
  USING (
    is_admin() OR 
    EXISTS (
        SELECT 1 FROM public.clinical_sessions s 
        WHERE s.id = session_id AND s.psychologist_id = (SELECT auth.uid())
    )
  );
-- 3. user_roles
DROP POLICY IF EXISTS "user_roles_manage" ON public.user_roles;
DROP POLICY IF EXISTS "user_roles_select" ON public.user_roles;
-- Single SELECT policy
CREATE POLICY "user_roles_select" ON public.user_roles
  FOR SELECT TO authenticated 
  USING (is_admin() OR (SELECT auth.uid()) = user_id);
-- Specific write policies for admins
CREATE POLICY "user_roles_insert" ON public.user_roles
  FOR INSERT TO authenticated WITH CHECK (is_admin());
CREATE POLICY "user_roles_update" ON public.user_roles
  FOR UPDATE TO authenticated USING (is_admin());
CREATE POLICY "user_roles_delete" ON public.user_roles
  FOR DELETE TO authenticated USING (is_admin());
