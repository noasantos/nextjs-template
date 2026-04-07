CREATE OR REPLACE FUNCTION public.create_session_with_calendar(
  p_psychologist_id uuid,
  p_patient_id uuid,
  p_start_time timestamp with time zone,
  p_duration_minutes integer DEFAULT 50,
  p_service_id uuid DEFAULT NULL,
  p_location_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_custom_price_cents integer DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_recurrence_rule text DEFAULT NULL,
  p_timezone text DEFAULT 'America/Sao_Paulo',
  p_session_type_id uuid DEFAULT NULL,
  p_session_number integer DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  v_result := public.create_session_occurrence_atomic(
    p_psychologist_id => p_psychologist_id,
    p_patient_id => p_patient_id,
    p_start_time => p_start_time,
    p_duration_minutes => p_duration_minutes,
    p_service_id => p_service_id,
    p_location_id => p_location_id,
    p_notes => p_notes,
    p_custom_price_cents => p_custom_price_cents,
    p_status => p_status,
    p_recurrence_rule => p_recurrence_rule,
    p_timezone => p_timezone,
    p_session_type_id => p_session_type_id,
    p_session_number => p_session_number
  );

  RETURN jsonb_build_object(
    'session_id', v_result ->> 'session_id',
    'event_id', v_result ->> 'event_id',
    'note_id', v_result ->> 'note_id',
    'details_id', v_result ->> 'details_id',
    'charge_id', v_result ->> 'charge_id',
    'status', v_result ->> 'status',
    'effective_price', (v_result ->> 'effective_price')::integer,
    'billing_eligible_now', COALESCE((v_result ->> 'billing_eligible_now')::boolean, false),
    'billing_pending', COALESCE((v_result ->> 'billing_pending')::boolean, false)
  );
END;
$$;
