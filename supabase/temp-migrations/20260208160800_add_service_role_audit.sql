-- supabase/migrations/20260208160800_add_service_role_audit.sql

CREATE TABLE IF NOT EXISTS public.service_role_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation TEXT NOT NULL,
  table_name TEXT,
  record_id TEXT,
  user_id UUID,
  source TEXT NOT NULL, -- Which function/file used service role
  ip_address TEXT,
  user_agent TEXT,
  query_text TEXT, -- Sanitized query
  duration_ms INTEGER, -- Operation duration
  success BOOLEAN,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
-- Indexes for analysis
CREATE INDEX IF NOT EXISTS idx_service_role_audit_operation ON public.service_role_audit_log(operation, created_at);
CREATE INDEX IF NOT EXISTS idx_service_role_audit_source ON public.service_role_audit_log(source, created_at);
CREATE INDEX IF NOT EXISTS idx_service_role_audit_user ON public.service_role_audit_log(user_id, created_at);
-- Only service role can write
ALTER TABLE public.service_role_audit_log ENABLE ROW LEVEL SECURITY;
-- No read access (append-only, query via database admin)
CREATE POLICY service_role_audit_no_read ON public.service_role_audit_log
  FOR ALL TO authenticated USING (false);
-- Add retention policy (keeps 90 days)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs()
RETURNS void AS $$
BEGIN
  DELETE FROM public.service_role_audit_log
  WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
