-- Account deletion pipeline + standardized business security audit events.
-- Conservative by design: request/approve/process states, with explicit audit trail.

CREATE TABLE IF NOT EXISTS public.security_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid NULL,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'app'
);
CREATE INDEX IF NOT EXISTS idx_security_audit_events_actor ON public.security_audit_events(actor_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_audit_events_action ON public.security_audit_events(action, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_audit_events_correlation ON public.security_audit_events(correlation_id);
ALTER TABLE public.security_audit_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS security_audit_service_role_all ON public.security_audit_events;
CREATE POLICY security_audit_service_role_all
  ON public.security_audit_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
DROP POLICY IF EXISTS security_audit_actor_select_own ON public.security_audit_events;
CREATE POLICY security_audit_actor_select_own
  ON public.security_audit_events
  FOR SELECT
  TO authenticated
  USING (actor_id = auth.uid());
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  requested_by uuid NOT NULL,
  reason text NULL,
  status text NOT NULL DEFAULT 'requested' CHECK (
    status IN ('requested', 'approved', 'processing', 'completed', 'failed', 'cancelled')
  ),
  requested_at timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz NULL,
  processing_started_at timestamptz NULL,
  processed_at timestamptz NULL,
  failed_at timestamptz NULL,
  failure_reason text NULL,
  retention_until timestamptz NULL,
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_user ON public.account_deletion_requests(user_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_status ON public.account_deletion_requests(status, requested_at ASC);
CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_correlation ON public.account_deletion_requests(correlation_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_account_deletion_requests_open_per_user
  ON public.account_deletion_requests(user_id)
  WHERE status IN ('requested', 'approved', 'processing');
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS account_deletion_requests_service_role_all ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_service_role_all
  ON public.account_deletion_requests
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
DROP POLICY IF EXISTS account_deletion_requests_insert_own ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_insert_own
  ON public.account_deletion_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (requested_by = auth.uid() AND user_id = auth.uid());
DROP POLICY IF EXISTS account_deletion_requests_select_own ON public.account_deletion_requests;
CREATE POLICY account_deletion_requests_select_own
  ON public.account_deletion_requests
  FOR SELECT
  TO authenticated
  USING (requested_by = auth.uid());
CREATE OR REPLACE FUNCTION public.log_security_audit_event(
  p_actor_id uuid,
  p_action text,
  p_target_type text,
  p_target_id text,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_correlation_id uuid DEFAULT gen_random_uuid(),
  p_source text DEFAULT 'app'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_event_id uuid;
BEGIN
  INSERT INTO public.security_audit_events (
    actor_id,
    action,
    target_type,
    target_id,
    metadata,
    correlation_id,
    source
  )
  VALUES (
    p_actor_id,
    p_action,
    p_target_type,
    p_target_id,
    COALESCE(p_metadata, '{}'::jsonb),
    COALESCE(p_correlation_id, gen_random_uuid()),
    COALESCE(p_source, 'app')
  )
  RETURNING id INTO v_event_id;

  RETURN v_event_id;
END;
$$;
CREATE OR REPLACE FUNCTION public.request_account_deletion(
  p_reason text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_request_id uuid;
  v_correlation_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT correlation_id
    INTO v_correlation_id
  FROM public.account_deletion_requests
  WHERE user_id = v_user_id
    AND status IN ('requested', 'approved', 'processing')
  ORDER BY requested_at DESC
  LIMIT 1;

  IF v_correlation_id IS NOT NULL THEN
    RAISE EXCEPTION 'An active account deletion request already exists';
  END IF;

  INSERT INTO public.account_deletion_requests (
    user_id,
    requested_by,
    reason,
    status,
    metadata
  )
  VALUES (
    v_user_id,
    v_user_id,
    p_reason,
    'requested',
    COALESCE(p_metadata, '{}'::jsonb)
  )
  RETURNING id, correlation_id INTO v_request_id, v_correlation_id;

  PERFORM public.log_security_audit_event(
    v_user_id,
    'account_deletion_requested',
    'user',
    v_user_id::text,
    jsonb_build_object(
      'request_id', v_request_id,
      'reason', p_reason
    ),
    v_correlation_id,
    'rpc'
  );

  RETURN v_request_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_security_audit_event(uuid, text, text, text, jsonb, uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_account_deletion(text, jsonb) TO authenticated;
