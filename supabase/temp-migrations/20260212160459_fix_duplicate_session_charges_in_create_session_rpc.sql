BEGIN;
-- 1) Clean existing duplicate charges per session, keeping canonical charge.
WITH ranked AS (
  SELECT
    c.id,
    c.session_id,
    ROW_NUMBER() OVER (
      PARTITION BY c.session_id
      ORDER BY
        (c.id = cs.default_charge_id) DESC,
        (c.payment_status = 'paid') DESC,
        c.created_at ASC,
        c.id ASC
    ) AS rn
  FROM public.psychologist_client_charges c
  LEFT JOIN public.clinical_sessions cs ON cs.id = c.session_id
  WHERE c.session_id IS NOT NULL
),
removed AS (
  DELETE FROM public.psychologist_client_charges c
  USING ranked r
  WHERE c.id = r.id
    AND r.rn > 1
  RETURNING c.session_id
),
canonical AS (
  SELECT DISTINCT ON (c.session_id)
    c.session_id,
    c.id AS canonical_charge_id
  FROM public.psychologist_client_charges c
  WHERE c.session_id IS NOT NULL
  ORDER BY c.session_id, c.created_at ASC, c.id ASC
)
UPDATE public.clinical_sessions cs
SET
  default_charge_id = canonical.canonical_charge_id,
  updated_at = NOW()
FROM canonical
WHERE cs.id = canonical.session_id
  AND (
    cs.default_charge_id IS NULL
    OR NOT EXISTS (
      SELECT 1
      FROM public.psychologist_client_charges cx
      WHERE cx.id = cs.default_charge_id
    )
  );
-- 2) Enforce one charge per session for linked charges.
CREATE UNIQUE INDEX IF NOT EXISTS ux_psychologist_client_charges_session_id
  ON public.psychologist_client_charges (session_id)
  WHERE session_id IS NOT NULL;
-- 3) Update RPC to upsert charge by session_id instead of inserting duplicates.
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
  v_session_id uuid;
  v_event_id uuid;
  v_note_id uuid;
  v_details_id uuid;
  v_charge_id uuid;
  v_patient_record record;
  v_service_record record;
  v_negotiated_price integer;
  v_effective_price integer;
  v_snapshot_service_name text;
  v_session_status public.clinical_session_status;
  v_calendar_status public.calendar_event_status;
  v_end_time timestamptz;
  v_patient_name text;
  v_event_title text;
  v_empty_note_content text;
  v_charge_date timestamptz;
BEGIN
  IF p_psychologist_id IS NULL THEN
    RAISE EXCEPTION 'psychologist_id is required';
  END IF;

  IF p_patient_id IS NULL THEN
    RAISE EXCEPTION 'patient_id (psychologist_client_id) is required';
  END IF;

  IF p_start_time IS NULL THEN
    RAISE EXCEPTION 'start_time is required';
  END IF;

  IF p_duration_minutes < 15 OR p_duration_minutes > 240 THEN
    RAISE EXCEPTION 'duration_minutes must be between 15 and 240';
  END IF;

  SELECT
    id,
    default_session_price,
    manual_full_name,
    synced_full_name
  INTO v_patient_record
  FROM public.psychologist_clients
  WHERE id = p_patient_id
    AND psychologist_id = p_psychologist_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Patient not found or does not belong to psychologist';
  END IF;

  v_effective_price := NULL;
  v_snapshot_service_name := NULL;

  IF p_service_id IS NOT NULL THEN
    SELECT
      ps.price,
      ps.name AS service_name,
      psc.name AS catalog_name
    INTO v_service_record
    FROM public.psychologist_services ps
    LEFT JOIN public.psychological_services_catalog psc ON psc.id = ps.catalog_id
    WHERE ps.id = p_service_id
      AND ps.psychologist_id = p_psychologist_id;

    IF FOUND THEN
      v_effective_price := v_service_record.price;
      v_snapshot_service_name := COALESCE(v_service_record.catalog_name, v_service_record.service_name);

      SELECT price_cents
      INTO v_negotiated_price
      FROM public.psychologist_client_services
      WHERE psychologist_id = p_psychologist_id
        AND psychologist_client_id = p_patient_id
        AND service_id = p_service_id;

      IF FOUND THEN
        v_effective_price := v_negotiated_price;
      END IF;
    END IF;
  END IF;

  IF v_effective_price IS NULL AND v_patient_record.default_session_price IS NOT NULL THEN
    v_effective_price := v_patient_record.default_session_price;
  END IF;

  IF p_custom_price_cents IS NOT NULL THEN
    v_effective_price := p_custom_price_cents;
  END IF;

  IF p_status IS NOT NULL THEN
    v_session_status := p_status::public.clinical_session_status;
  ELSE
    IF p_start_time < NOW() THEN
      v_session_status := 'open'::public.clinical_session_status;
    ELSE
      v_session_status := 'scheduled'::public.clinical_session_status;
    END IF;
  END IF;

  CASE v_session_status
    WHEN 'cancelled' THEN v_calendar_status := 'cancelled'::public.calendar_event_status;
    WHEN 'no_show' THEN v_calendar_status := 'no_show'::public.calendar_event_status;
    WHEN 'completed' THEN v_calendar_status := 'completed'::public.calendar_event_status;
    ELSE v_calendar_status := 'scheduled'::public.calendar_event_status;
  END CASE;

  v_end_time := p_start_time + (p_duration_minutes || ' minutes')::interval;

  v_patient_name := COALESCE(
    v_patient_record.manual_full_name,
    v_patient_record.synced_full_name,
    'Paciente'
  );
  v_event_title := 'Sessao - ' || v_patient_name;

  v_empty_note_content := encode(
    convert_to(
      '{"root":{"children":[{"children":[],"direction":null,"format":"","indent":0,"type":"paragraph","version":1,"textFormat":0,"textStyle":""}],"direction":null,"format":"","indent":0,"type":"root","version":1}}',
      'UTF8'
    ),
    'base64'
  );

  INSERT INTO public.clinical_sessions (
    psychologist_id,
    psychologist_client_id,
    start_time,
    duration_minutes,
    psychologist_service_id,
    location_id,
    snapshot_service_name,
    snapshot_price_cents,
    notes,
    status,
    created_by,
    created_at,
    updated_at
  ) VALUES (
    p_psychologist_id,
    p_patient_id,
    p_start_time,
    p_duration_minutes,
    p_service_id,
    p_location_id,
    v_snapshot_service_name,
    v_effective_price,
    p_notes,
    v_session_status,
    p_psychologist_id,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_session_id;

  INSERT INTO public.calendar_events (
    psychologist_id,
    event_type,
    title,
    description,
    start_datetime,
    end_datetime,
    duration_minutes,
    timezone,
    all_day,
    status,
    source,
    google_sync_status,
    private_notes,
    metadata,
    created_at,
    updated_at
  ) VALUES (
    p_psychologist_id,
    'session',
    v_event_title,
    p_notes,
    p_start_time,
    v_end_time,
    p_duration_minutes,
    p_timezone,
    FALSE,
    v_calendar_status,
    'fluri',
    'pending',
    NULL,
    jsonb_build_object(
      'patient_id', p_patient_id,
      'clinical_session_id', v_session_id,
      'session_type_id', p_session_type_id,
      'service_id', p_service_id,
      'location_id', p_location_id,
      'price', v_effective_price,
      'session_number', p_session_number,
      'recurrence_rule', p_recurrence_rule
    ),
    NOW(),
    NOW()
  )
  RETURNING id INTO v_event_id;

  INSERT INTO public.clinical_session_details (
    calendar_event_id,
    psychologist_client_id,
    clinical_session_id,
    session_type_id,
    psychologist_service_id,
    session_number,
    billing_status,
    attendance_confirmed,
    created_at,
    updated_at
  ) VALUES (
    v_event_id,
    p_patient_id,
    v_session_id,
    p_session_type_id,
    p_service_id,
    p_session_number,
    'pending',
    FALSE,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_details_id;

  INSERT INTO public.clinical_notes (
    psychologist_id,
    patient_id,
    session_id,
    note_type,
    encoded_content,
    title,
    is_archived,
    created_by,
    created_at,
    updated_at
  ) VALUES (
    p_psychologist_id,
    p_patient_id,
    v_session_id,
    'clinical_note',
    v_empty_note_content,
    'Nota da Sessao',
    FALSE,
    p_psychologist_id,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_note_id;

  v_charge_id := NULL;
  IF v_effective_price IS NOT NULL AND v_effective_price > 0 THEN
    v_charge_date := ((p_start_time AT TIME ZONE p_timezone)::date || ' 12:00:00+00')::timestamptz;

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
      p_psychologist_id,
      p_patient_id,
      v_session_id,
      v_effective_price,
      (p_start_time AT TIME ZONE p_timezone)::date,
      'pending',
      COALESCE(v_snapshot_service_name, 'Sessão de Terapia'),
      p_psychologist_id,
      p_psychologist_id,
      v_charge_date,
      NOW()
    )
    ON CONFLICT (session_id) WHERE session_id IS NOT NULL
    DO UPDATE SET
      psychologist_client_id = EXCLUDED.psychologist_client_id,
      price_cents = EXCLUDED.price_cents,
      due_date = EXCLUDED.due_date,
      description = EXCLUDED.description,
      created_at = EXCLUDED.created_at,
      updated_at = NOW(),
      updated_by = p_psychologist_id,
      payment_status = CASE
        WHEN public.psychologist_client_charges.payment_status = 'paid' THEN public.psychologist_client_charges.payment_status
        ELSE 'pending'
      END
    RETURNING id INTO v_charge_id;
  ELSE
    DELETE FROM public.psychologist_client_charges
    WHERE session_id = v_session_id
      AND payment_status = 'pending';
    v_charge_id := NULL;
  END IF;

  UPDATE public.clinical_sessions
  SET
    note_id = v_note_id,
    default_charge_id = v_charge_id,
    updated_at = NOW()
  WHERE id = v_session_id;

  RETURN jsonb_build_object(
    'session_id', v_session_id,
    'event_id', v_event_id,
    'note_id', v_note_id,
    'details_id', v_details_id,
    'charge_id', v_charge_id,
    'status', v_session_status::text,
    'effective_price', v_effective_price
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to create session: %', SQLERRM;
END;
$$;
COMMIT;
