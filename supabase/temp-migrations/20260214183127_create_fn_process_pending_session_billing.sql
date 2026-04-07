CREATE OR REPLACE FUNCTION public.process_pending_session_billing(
  p_limit integer DEFAULT 200,
  p_lead_days integer DEFAULT 7
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_candidate record;
  v_result jsonb;
  v_processed integer := 0;
  v_charged integer := 0;
  v_failed integer := 0;
  v_skipped integer := 0;
BEGIN
  FOR v_candidate IN
    WITH candidates AS (
      SELECT
        cs.id AS session_id,
        cs.psychologist_id
      FROM public.clinical_session_details sd
      JOIN public.clinical_sessions cs
        ON cs.id = sd.clinical_session_id
      WHERE sd.clinical_session_id IS NOT NULL
        AND sd.billing_status IN ('pending', 'pending_window', 'ready_to_charge', 'charge_failed')
        AND cs.status NOT IN ('cancelled', 'no_show')
        AND COALESCE(cs.snapshot_price_cents, 0) > 0
        AND cs.start_time <= (now() + make_interval(days => p_lead_days))
        AND (sd.billing_next_attempt_at IS NULL OR sd.billing_next_attempt_at <= now())
      ORDER BY cs.start_time ASC
      LIMIT p_limit
      FOR UPDATE OF sd SKIP LOCKED
    )
    SELECT * FROM candidates
  LOOP
    v_processed := v_processed + 1;

    v_result := public.create_session_charge_if_due(
      v_candidate.session_id,
      v_candidate.psychologist_id,
      p_lead_days,
      false,
      format('charge:session:%s:v1', v_candidate.session_id)
    );

    IF COALESCE(v_result ->> 'reason', '') = 'error' THEN
      v_failed := v_failed + 1;
    ELSIF NULLIF(v_result ->> 'charge_id', '') IS NOT NULL THEN
      v_charged := v_charged + 1;
    ELSE
      v_skipped := v_skipped + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'processed', v_processed,
    'charged', v_charged,
    'failed', v_failed,
    'skipped', v_skipped,
    'lead_days', p_lead_days,
    'limit', p_limit,
    'processed_at', now()
  );
END;
$$;
