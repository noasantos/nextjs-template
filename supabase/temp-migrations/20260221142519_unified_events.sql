-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-21T14:25:19Z

CREATE TABLE unified_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_family TEXT NOT NULL CHECK (event_family IN ('security_audit', 'operational', 'stripe_webhook')),
  event_name TEXT NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  trace_id UUID NOT NULL DEFAULT gen_random_uuid(),
  correlation_id UUID,
  service TEXT NOT NULL,
  component TEXT NOT NULL,
  environment TEXT NOT NULL CHECK (environment IN ('local', 'dev', 'stg', 'prod')),
  actor_type TEXT NOT NULL CHECK (actor_type IN ('anonymous', 'authenticated', 'system', 'service-role')),
  actor_id_hash TEXT,
  role TEXT,
  operation TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  outcome TEXT NOT NULL CHECK (outcome IN ('success', 'failure', 'error', 'timeout', 'circuit_open', 'rate_limited', 'received', 'processed')),
  error_category TEXT,
  error_code TEXT,
  error_message TEXT,
  duration_ms INTEGER,
  metadata JSONB DEFAULT '{}',
  sample_rate FLOAT NOT NULL DEFAULT 1.0,
  force_keep BOOLEAN NOT NULL DEFAULT true,
  retention_days INTEGER DEFAULT 90,
  request_path TEXT,
  http_status INTEGER,
  ip_address TEXT,
  user_agent TEXT
);
CREATE INDEX idx_unified_time ON unified_events(timestamp DESC);
CREATE INDEX idx_unified_family ON unified_events(event_family, timestamp DESC);
CREATE INDEX idx_unified_service ON unified_events(service, component, timestamp DESC);
CREATE INDEX idx_unified_metadata ON unified_events USING GIN (metadata jsonb_path_ops);
CREATE OR REPLACE VIEW v_service_role_audit AS SELECT * FROM unified_events WHERE event_family = 'security_audit';
CREATE OR REPLACE VIEW v_operational_events AS SELECT * FROM unified_events WHERE event_family = 'operational';
CREATE OR REPLACE VIEW v_stripe_webhook_events AS SELECT id, timestamp, event_name, operation as stripe_event_type, metadata->>'stripe_event_id' as stripe_event_id, metadata->>'customer_id' as customer_id, metadata->>'subscription_id' as subscription_id, outcome, error_message, duration_ms FROM unified_events WHERE event_family = 'stripe_webhook';
