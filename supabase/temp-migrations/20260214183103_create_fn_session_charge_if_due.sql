CREATE OR REPLACE FUNCTION public.create_session_charge_if_due(
  p_session_id uuid,
  p_psychologist_id uuid,
  p_lead_days integer DEFAULT 7,
  p_force boolean DEFAULT false,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session record;
  v_charge_id uuid;
  v_due_date date;
  v_charge_created_at timestamptz;
  v_timezone text;
  v_next_attempt_at timestamptz;
  v_eligible_now boolean;
BEGIN
  IF p_session_id IS NULL THEN
    RAISE EXCEPTION 'session_id is required';
  END IF;

  IF p_psychologist_id IS NULL THEN
    RAISE EXCEPTION 'psychologist_id is required';
  END IF;

  IF p_lead_days < 0 THEN
    RAISE EXCEPTION 'lead_days must be >= 0';
  END IF;

  SELECT
    cs.id,
    cs.psychologist_id,
    cs.psychologist_client_id,
    cs.start_time,
    cs.status,
    cs.snapshot_price_cents,
    cs.snapshot_service_name,
    cs.default_charge_id,
    COALESCE(ce.timezone, 'America/Sao_Paulo') AS timezone
  INTO v_session
  FROM public.clinical_sessions cs
  LEFT JOIN public.clinical_session_details sd
    ON sd.clinical_session_id = cs.id
  LEFT JOIN public.calendar_events ce
    ON ce.id = sd.calendar_event_id
  WHERE cs.id = p_session_id
    AND cs.psychologist_id = p_psychologist_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Session not found or does not belong to psychologist';
  END IF;

  IF v_session.status IN ('cancelled', 'no_show') THEN
    UPDATE public.psychologist_client_charges
    SET
      payment_status = 'cancelled',
      updated_at = now(),
      updated_by = p_psychologist_id
    WHERE session_id = p_session_id
      AND payment_status = 'pending';

    UPDATE public.clinical_session_details
    SET
      billing_status = 'canceled',
      billing_next_attempt_at = NULL,
      billing_last_error = NULL,
      updated_at = now()
    WHERE clinical_session_id = p_session_id;

    RETURN jsonb_build_object(
      'session_id', p_session_id,
      'charge_id', NULL,
      'eligible_now', false,
      'created', false,
      'reason', 'session_not_billable'
    );
  END IF;

  IF COALESCE(v_session.snapshot_price_cents, 0) <= 0 THEN
    UPDATE public.clinical_session_details
    SET
      billing_status = 'canceled',
      billing_next_attempt_at = NULL,
      billing_last_error = NULL,
      updated_at = now()
    WHERE clinical_session_id = p_session_id;

    DELETE FROM public.psychologist_client_charges
    WHERE session_id = p_session_id
      AND payment_status = 'pending';

    RETURN jsonb_build_object(
      'session_id', p_session_id,
      'charge_id', NULL,
      'eligible_now', false,
      'created', false,
      'reason', 'non_billable_session'
    );
  END IF;

  v_eligible_now := p_force OR v_session.start_time <= (now() + make_interval(days => p_lead_days));

  IF NOT v_eligible_now THEN
    v_next_attempt_at := GREATEST(now(), v_session.start_time - make_interval(days => p_lead_days));
    v_timezone := COALESCE(NULLIF(v_session.timezone, ''), 'America/Sao_Paulo');
    v_due_date := (v_session.start_time AT TIME ZONE v_timezone)::date;

    UPDATE public.psychologist_client_charges
    SET
      due_date = v_due_date,
      description = COALESCE(v_session.snapshot_service_name, public.psychologist_client_charges.description),
      updated_at = now(),
      updated_by = p_psychologist_id
    WHERE session_id = p_session_id
      AND payment_status = 'pending';

    UPDATE public.clinical_session_details
    SET
      billing_status = 'pending_window',
      billing_next_attempt_at = v_next_attempt_at,
      billing_last_error = NULL,
      updated_at = now()
    WHERE clinical_session_id = p_session_id;

    RETURN jsonb_build_object(
      'session_id', p_session_id,
      'charge_id', NULL,
      'eligible_now', false,
      'created', false,
      'reason', 'outside_lead_window',
      'next_attempt_at', v_next_attempt_at
    );
  END IF;

  v_timezone := COALESCE(NULLIF(v_session.timezone, ''), 'America/Sao_Paulo');
  v_due_date := (v_session.start_time AT TIME ZONE v_timezone)::date;
  v_charge_created_at := ((v_due_date::text || ' 12:00:00+00')::timestamptz);

  INSERT INTO public.psychologist_client_charges (
    psychologist_id,
    psychologist_client_id,
    session_id,
    price_cents,
    due_date,
    payment_status,
    description,
    created_by,
    updated_by,
    created_at,
    updated_at
  ) VALUES (
    v_session.psychologist_id,
    v_session.psychologist_client_id,
    p_session_id,
    v_session.snapshot_price_cents,
    v_due_date,
    'pending',
    COALESCE(v_session.snapshot_service_name, 'Sessão de Terapia'),
    p_psychologist_id,
    p_psychologist_id,
    v_charge_created_at,
    now()
  )
  ON CONFLICT (session_id) WHERE session_id IS NOT NULL
  DO UPDATE SET
    psychologist_client_id = EXCLUDED.psychologist_client_id,
    price_cents = EXCLUDED.price_cents,
    due_date = EXCLUDED.due_date,
    description = EXCLUDED.description,
    updated_at = now(),
    updated_by = p_psychologist_id,
    payment_status = CASE
      WHEN public.psychologist_client_charges.payment_status = 'paid' THEN public.psychologist_client_charges.payment_status
      ELSE 'pending'
    END
  RETURNING id INTO v_charge_id;

  PERFORM set_config('app.fluri.skip_charge_triggers', 'on', true);

  UPDATE public.clinical_sessions
  SET
    default_charge_id = v_charge_id,
    updated_at = now(),
    updated_by = COALESCE(updated_by, p_psychologist_id)
  WHERE id = p_session_id;

  UPDATE public.clinical_session_details
  SET
    billing_status = 'charged',
    billing_attempt_count = COALESCE(billing_attempt_count, 0) + 1,
    billing_last_attempt_at = now(),
    billing_next_attempt_at = NULL,
    billing_last_error = NULL,
    updated_at = now()
  WHERE clinical_session_id = p_session_id;

  RETURN jsonb_build_object(
    'session_id', p_session_id,
    'charge_id', v_charge_id,
    'eligible_now', true,
    'created', true,
    'reason', 'charged_now',
    'idempotency_key', COALESCE(p_idempotency_key, format('charge:session:%s:v1', p_session_id))
  );
EXCEPTION
  WHEN OTHERS THEN
    UPDATE public.clinical_session_details
    SET
      billing_status = 'charge_failed',
      billing_attempt_count = COALESCE(billing_attempt_count, 0) + 1,
      billing_last_attempt_at = now(),
      billing_next_attempt_at = now() + interval '1 hour',
      billing_last_error = LEFT(SQLERRM, 500),
      updated_at = now()
    WHERE clinical_session_id = p_session_id;

    INSERT INTO public.session_billing_dead_letter (
      session_id,
      psychologist_id,
      error_message,
      context,
      attempts,
      updated_at
    ) VALUES (
      p_session_id,
      p_psychologist_id,
      LEFT(SQLERRM, 500),
      jsonb_build_object(
        'lead_days', p_lead_days,
        'forced', p_force,
        'idempotency_key', p_idempotency_key,
        'timestamp', now()
      ),
      1,
      now()
    )
    ON CONFLICT (session_id) WHERE resolved_at IS NULL
    DO UPDATE SET
      error_message = EXCLUDED.error_message,
      context = public.session_billing_dead_letter.context || EXCLUDED.context,
      attempts = public.session_billing_dead_letter.attempts + 1,
      updated_at = now();

    RETURN jsonb_build_object(
      'session_id', p_session_id,
      'charge_id', NULL,
      'eligible_now', false,
      'created', false,
      'reason', 'error',
      'error', SQLERRM
    );
END;
$$;
