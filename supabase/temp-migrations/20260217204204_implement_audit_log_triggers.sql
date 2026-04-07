-- Migration: implement_audit_log_triggers
-- Description: Create audit logging triggers for sensitive tables (LGPD/GDPR compliance)

-------------------------------------------------------------------------------
-- 1. MAIN AUDIT FUNCTION
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.process_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID;
  v_user_type TEXT;
  v_record_id TEXT;
  v_changed_fields JSONB;
  v_old_data JSONB;
  v_new_data JSONB;
  v_correlation_id UUID;
BEGIN
  -- Get current user ID from session
  v_user_id := auth.uid();
  
  -- Determine user type based on role
  SELECT role INTO v_user_type
  FROM public.user_roles
  WHERE user_id = v_user_id
  LIMIT 1;
  
  -- Default to 'unknown' if no role found
  IF v_user_type IS NULL THEN
    v_user_type := 'unknown';
  END IF;
  
  -- Generate correlation ID for tracing
  v_correlation_id := gen_random_uuid();
  
  -- Get record ID based on operation
  IF TG_OP = 'DELETE' THEN
    v_record_id := OLD.id::TEXT;
  ELSE
    v_record_id := NEW.id::TEXT;
  END IF;
  
  -- Build changed_fields based on operation
  CASE TG_OP
    WHEN 'INSERT' THEN
      v_new_data := to_jsonb(NEW);
      -- Remove sensitive fields (optional, based on requirements)
      v_changed_fields := jsonb_build_object(
        'new', v_new_data,
        'old', null
      );
      
    WHEN 'UPDATE' THEN
      v_old_data := to_jsonb(OLD);
      v_new_data := to_jsonb(NEW);
      
      -- Calculate diff (only changed fields)
      SELECT jsonb_object_agg(key, value)
      INTO v_changed_fields
      FROM jsonb_each(v_new_data)
      WHERE v_old_data->key IS DISTINCT FROM value;
      
      v_changed_fields := jsonb_build_object(
        'old', v_old_data,
        'new', v_new_data,
        'changed', v_changed_fields
      );
      
    WHEN 'DELETE' THEN
      v_old_data := to_jsonb(OLD);
      v_changed_fields := jsonb_build_object(
        'old', v_old_data,
        'new', null
      );
  END CASE;
  
  -- Insert audit log
  INSERT INTO public.audit_logs (
    user_id,
    user_type,
    table_name,
    record_id,
    action,
    changed_fields,
    correlation_id,
    created_at
  ) VALUES (
    v_user_id,
    v_user_type,
    TG_TABLE_NAME,
    v_record_id,
    TG_OP,
    v_changed_fields,
    v_correlation_id,
    NOW()
  );
  
  -- Return appropriate row based on operation
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;
COMMENT ON FUNCTION public.process_audit_log() IS 'Generic audit logging function for tracking changes to sensitive tables. Captures INSERT, UPDATE, DELETE operations with full data snapshots.';
-------------------------------------------------------------------------------
-- 2. AUDIT TRIGGERS FOR SENSITIVE TABLES
-------------------------------------------------------------------------------

-- 2.1 Psychologist Patients (patient data)
DROP TRIGGER IF EXISTS tr_audit_psychologist_patients ON public.psychologist_patients;
CREATE TRIGGER tr_audit_psychologist_patients
  AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_patients
  FOR EACH ROW
  EXECUTE FUNCTION public.process_audit_log();
COMMENT ON TRIGGER tr_audit_psychologist_patients ON public.psychologist_patients IS 'Audit logging for patient demographic and contact data';
-- 2.2 Psychologist Notes (clinical notes)
DROP TRIGGER IF EXISTS tr_audit_psychologist_notes ON public.psychologist_notes;
CREATE TRIGGER tr_audit_psychologist_notes
  AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_notes
  FOR EACH ROW
  EXECUTE FUNCTION public.process_audit_log();
COMMENT ON TRIGGER tr_audit_psychologist_notes ON public.psychologist_notes IS 'Audit logging for clinical notes and patient history (high sensitivity)';
-- 2.3 Psychologist Clinical Sessions (appointments)
DROP TRIGGER IF EXISTS tr_audit_psychologist_clinical_sessions ON public.psychologist_clinical_sessions;
CREATE TRIGGER tr_audit_psychologist_clinical_sessions
  AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_clinical_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.process_audit_log();
COMMENT ON TRIGGER tr_audit_psychologist_clinical_sessions ON public.psychologist_clinical_sessions IS 'Audit logging for appointment history and scheduling changes';
-- 2.4 Psychologist Financial Entries (billing)
DROP TRIGGER IF EXISTS tr_audit_psychologist_financial_entries ON public.psychologist_financial_entries;
CREATE TRIGGER tr_audit_psychologist_financial_entries
  AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_financial_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.process_audit_log();
COMMENT ON TRIGGER tr_audit_psychologist_financial_entries ON public.psychologist_financial_entries IS 'Audit logging for billing and payment history';
-- 2.5 Psychologist Assistants (access control)
DROP TRIGGER IF EXISTS tr_audit_psychologist_assistants ON public.psychologist_assistants;
CREATE TRIGGER tr_audit_psychologist_assistants
  AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_assistants
  FOR EACH ROW
  EXECUTE FUNCTION public.process_audit_log();
COMMENT ON TRIGGER tr_audit_psychologist_assistants ON public.psychologist_assistants IS 'Audit logging for access control changes (who can see whose data)';
-- 2.6 Psychologist Patient Charges (charges/financial)
DROP TRIGGER IF EXISTS tr_audit_psychologist_patient_charges ON public.psychologist_patient_charges;
CREATE TRIGGER tr_audit_psychologist_patient_charges
  AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_patient_charges
  FOR EACH ROW
  EXECUTE FUNCTION public.process_audit_log();
COMMENT ON TRIGGER tr_audit_psychologist_patient_charges ON public.psychologist_patient_charges IS 'Audit logging for patient charges';
-- 2.7 User Roles (role assignments)
DROP TRIGGER IF EXISTS tr_audit_user_roles ON public.user_roles;
CREATE TRIGGER tr_audit_user_roles
  AFTER INSERT OR UPDATE OR DELETE ON public.user_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.process_audit_log();
COMMENT ON TRIGGER tr_audit_user_roles ON public.user_roles IS 'Audit logging for role assignments';
-------------------------------------------------------------------------------
-- 3. FUNCTION: Query audit logs with filtering
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.query_audit_logs(
  p_table_name TEXT DEFAULT NULL,
  p_record_id TEXT DEFAULT NULL,
  p_action TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL,
  p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  user_type TEXT,
  table_name TEXT,
  record_id TEXT,
  action TEXT,
  changed_fields JSONB,
  correlation_id UUID,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    al.id,
    al.user_id,
    al.user_type,
    al.table_name,
    al.record_id,
    al.action,
    al.changed_fields,
    al.correlation_id,
    al.created_at
  FROM public.audit_logs al
  WHERE (p_table_name IS NULL OR al.table_name = p_table_name)
    AND (p_record_id IS NULL OR al.record_id = p_record_id)
    AND (p_action IS NULL OR al.action = p_action)
    AND (p_user_id IS NULL OR al.user_id = p_user_id)
    AND (p_start_date IS NULL OR al.created_at >= p_start_date)
    AND (p_end_date IS NULL OR al.created_at <= p_end_date)
  ORDER BY al.created_at DESC
  LIMIT p_limit;
END;
$$;
COMMENT ON FUNCTION public.query_audit_logs(TEXT, TEXT, TEXT, UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER) IS 'Query audit logs with optional filtering. Used for compliance reporting and investigation.';
-------------------------------------------------------------------------------
-- 4. FUNCTION: Get audit history for a specific record
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_record_audit_history(
  p_table_name TEXT,
  p_record_id TEXT,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  action TEXT,
  user_id UUID,
  user_type TEXT,
  changed_fields JSONB,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    al.action,
    al.user_id,
    al.user_type,
    al.changed_fields,
    al.created_at
  FROM public.audit_logs al
  WHERE al.table_name = p_table_name
    AND al.record_id = p_record_id
  ORDER BY al.created_at DESC
  LIMIT p_limit;
END;
$$;
COMMENT ON FUNCTION public.get_record_audit_history(TEXT, TEXT, INTEGER) IS 'Get complete audit history for a specific record. Useful for data lineage and compliance investigations.';
-------------------------------------------------------------------------------
-- 5. FUNCTION: Cleanup old audit logs (retention policy)
-------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cleanup_old_audit_logs(
  p_retention_days INTEGER DEFAULT 1825 -- 5 years default
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM public.audit_logs
  WHERE created_at < NOW() - (p_retention_days || ' days')::INTERVAL;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN v_deleted_count;
END;
$$;
COMMENT ON FUNCTION public.cleanup_old_audit_logs(INTEGER) IS 'Removes audit logs older than the specified retention period. Default is 5 years (LGPD/GDPR compliance).';
-------------------------------------------------------------------------------
-- 6. RLS POLICIES FOR AUDIT LOGS
-------------------------------------------------------------------------------

-- Ensure RLS is enabled
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
-- Only admins can view all audit logs
DROP POLICY IF EXISTS "Admins can view all audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view all audit logs"
  ON public.audit_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_admins
      WHERE id = auth.uid()
      AND is_active = true
    )
  );
-- Psychologists can view audit logs for their own records
DROP POLICY IF EXISTS "Psychologists can view own audit logs" ON public.audit_logs;
CREATE POLICY "Psychologists can view own audit logs"
  ON public.audit_logs
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR
    -- Can view logs for records they own (patients, sessions, etc.)
    EXISTS (
      SELECT 1 FROM public.psychologist_patients pp
      WHERE pp.psychologist_id = auth.uid()
      AND pp.id::TEXT = audit_logs.record_id
    )
    OR
    EXISTS (
      SELECT 1 FROM public.psychologist_clinical_sessions pcs
      WHERE pcs.psychologist_id = auth.uid()
      AND pcs.id::TEXT = audit_logs.record_id
    )
    OR
    EXISTS (
      SELECT 1 FROM public.psychologist_notes pn
      WHERE pn.psychologist_id = auth.uid()
      AND pn.id::TEXT = audit_logs.record_id
    )
  );
-- No one can insert/update/delete audit logs directly (only via triggers)
DROP POLICY IF EXISTS "No direct modifications to audit logs" ON public.audit_logs;
CREATE POLICY "No direct modifications to audit logs"
  ON public.audit_logs
  FOR ALL
  TO authenticated
  USING (false)
  WITH CHECK (false);
-------------------------------------------------------------------------------
-- 7. TABLE DESCRIPTIONS
-------------------------------------------------------------------------------

COMMENT ON TABLE public.audit_logs IS 'Central repository for security and operational auditing. Tracks all changes to sensitive data for LGPD/GDPR compliance. DO NOT MODIFY DIRECTLY - use triggers only.';
COMMENT ON COLUMN public.audit_logs.user_id IS 'ID of the user who made the change';
COMMENT ON COLUMN public.audit_logs.user_type IS 'Role of the user (psychologist, admin, assistant, etc.)';
COMMENT ON COLUMN public.audit_logs.table_name IS 'Table that was modified';
COMMENT ON COLUMN public.audit_logs.record_id IS 'ID of the record that was modified';
COMMENT ON COLUMN public.audit_logs.action IS 'Operation type: INSERT, UPDATE, DELETE';
COMMENT ON COLUMN public.audit_logs.changed_fields IS 'JSONB containing old/new values and diff';
COMMENT ON COLUMN public.audit_logs.correlation_id IS 'UUID for tracing across distributed systems';
COMMENT ON COLUMN public.audit_logs.ip_address IS 'IP address of the user (if available)';
COMMENT ON COLUMN public.audit_logs.user_agent IS 'User agent string (if available)';
