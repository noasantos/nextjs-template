-- Migration: Add webhook audit log for non-financial webhooks
CREATE TABLE IF NOT EXISTS public.webhook_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source TEXT NOT NULL, -- 'google_calendar', etc.
  event_id TEXT,
  channel_id TEXT,
  resource_id TEXT,
  event_type TEXT,
  payload_hash TEXT, -- Hash of payload for integrity
  processed BOOLEAN DEFAULT false,
  processing_error TEXT,
  ip_address TEXT,
  received_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_webhook_audit_source_event ON public.webhook_audit_log(source, event_id);
CREATE INDEX IF NOT EXISTS idx_webhook_audit_received_at ON public.webhook_audit_log(received_at);
-- Enable RLS
ALTER TABLE public.webhook_audit_log ENABLE ROW LEVEL SECURITY;
-- Only service role can access
DROP POLICY IF EXISTS webhook_audit_service_only ON public.webhook_audit_log;
CREATE POLICY webhook_audit_service_only ON public.webhook_audit_log
  FOR ALL TO authenticated USING (false);
