-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-03-02T12:58:59Z
-- Migration: drop_legacy_service_role_audit_log
-- Description: Remove legacy service_role_audit_log table - superseded by unified_events
-- ADR Reference: 009-unified-events-logging.md

-- 1. Drop dependent objects (policies, triggers, functions that reference the table)
DROP POLICY IF EXISTS "service_role_audit_log_service_role_all" ON public.service_role_audit_log;

-- 2. Drop the table
-- Note: Data should have been migrated to unified_events via dual-write during transition period
DROP TABLE IF EXISTS public.service_role_audit_log;

-- 3. Clean up any references in query whitelist (edge functions handle this in code)
-- No action needed - whitelist updated in code

-- 4. Add comment documenting the change
COMMENT ON TABLE public.unified_events IS 'Central repository for all operational events. Replaces service_role_audit_log. See ADR 009 for details.';
