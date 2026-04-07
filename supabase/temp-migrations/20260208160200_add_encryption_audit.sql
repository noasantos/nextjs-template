-- TM-003: Add Encryption Audit Log
-- Purpose: Track all 'encrypt' and 'decrypt' operations to detect potential token theft

CREATE TABLE IF NOT EXISTS public.encryption_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation TEXT NOT NULL, -- 'encrypt', 'decrypt'
  success BOOLEAN NOT NULL,
  error_message TEXT,
  caller_role TEXT DEFAULT current_user,
  caller_user_id UUID, -- When available via auth.uid()
  context TEXT, -- 'google_calendar', 'stripe', etc.
  attempted_at TIMESTAMPTZ DEFAULT NOW()
);
-- Index for auditing and performance monitoring
CREATE INDEX idx_encryption_audit_operation ON public.encryption_audit_log(operation, attempted_at);
CREATE INDEX idx_encryption_audit_user ON public.encryption_audit_log(caller_user_id);
-- Enable RLS
ALTER TABLE public.encryption_audit_log ENABLE ROW LEVEL SECURITY;
-- Only service_role can view audit logs
CREATE POLICY encryption_audit_service_view ON public.encryption_audit_log
  FOR SELECT TO service_role USING (true);
-- No one else can view these logs
CREATE POLICY encryption_audit_deny_public ON public.encryption_audit_log
  FOR ALL TO public USING (false);
