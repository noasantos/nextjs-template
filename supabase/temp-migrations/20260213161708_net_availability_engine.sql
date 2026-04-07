-- ============================================================================
-- Net Availability Engine
-- Deterministic, conflict-safe scheduling with projection table strategy
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Enable btree_gist extension (required for exclusion constraints on UUIDs + ranges)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA extensions;
-- ---------------------------------------------------------------------------
-- 2. Projection table: busy_slots
--    Materialized view of all time ranges that block availability.
--    Sources: calendar_events, clinical_sessions, calendar_event_series (expanded)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.busy_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id uuid NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  slot_range tstzrange NOT NULL,
  source_type text NOT NULL CHECK (source_type IN ('calendar_event', 'clinical_session', 'series_expansion')),
  source_id uuid NOT NULL,
  event_type public.calendar_event_type,
  is_hard_block boolean NOT NULL DEFAULT true,
  title text,
  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT valid_slot_range CHECK (NOT isempty(slot_range)),
  CONSTRAINT unique_source UNIQUE (source_type, source_id)
);
-- Exclusion constraint: prevents overlapping busy slots for the same psychologist
ALTER TABLE public.busy_slots
  ADD CONSTRAINT no_overlapping_busy_slots
  EXCLUDE USING gist (
    psychologist_id WITH =,
    slot_range WITH &&
  )
  WHERE (is_hard_block = true);
-- ---------------------------------------------------------------------------
-- 3. Indexes for read performance
-- ---------------------------------------------------------------------------
CREATE INDEX idx_busy_slots_psychologist_range
  ON public.busy_slots
  USING gist (psychologist_id, slot_range);
CREATE INDEX idx_busy_slots_source
  ON public.busy_slots (source_type, source_id);
CREATE INDEX idx_busy_slots_psychologist_id
  ON public.busy_slots (psychologist_id);
-- ---------------------------------------------------------------------------
-- 4. RLS policies for busy_slots
-- ---------------------------------------------------------------------------
ALTER TABLE public.busy_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "busy_slots_owner_read"
  ON public.busy_slots FOR SELECT TO authenticated
  USING (psychologist_id = auth.uid());
CREATE POLICY "busy_slots_public_read"
  ON public.busy_slots FOR SELECT TO anon
  USING (true);
CREATE POLICY "busy_slots_service_manage"
  ON public.busy_slots FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);
-- ---------------------------------------------------------------------------
-- 5. Trigger function: sync calendar_events → busy_slots
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_calendar_event_to_busy_slots()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.busy_slots
    WHERE source_type = 'calendar_event' AND source_id = OLD.id;
    RETURN OLD;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status NOT IN ('cancelled', 'rescheduled') THEN
      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        NEW.psychologist_id,
        tstzrange(NEW.start_datetime, NEW.end_datetime, '[)'),
        'calendar_event',
        NEW.id,
        NEW.event_type,
        NEW.event_type IN ('session', 'block', 'supervision'),
        NEW.title
      )
      ON CONFLICT (source_type, source_id) DO UPDATE SET
        psychologist_id = EXCLUDED.psychologist_id,
        slot_range = EXCLUDED.slot_range,
        event_type = EXCLUDED.event_type,
        is_hard_block = EXCLUDED.is_hard_block,
        title = EXCLUDED.title;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.status IN ('cancelled', 'rescheduled') THEN
      DELETE FROM public.busy_slots
      WHERE source_type = 'calendar_event' AND source_id = NEW.id;
    ELSE
      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        NEW.psychologist_id,
        tstzrange(NEW.start_datetime, NEW.end_datetime, '[)'),
        'calendar_event',
        NEW.id,
        NEW.event_type,
        NEW.event_type IN ('session', 'block', 'supervision'),
        NEW.title
      )
      ON CONFLICT (source_type, source_id) DO UPDATE SET
        psychologist_id = EXCLUDED.psychologist_id,
        slot_range = EXCLUDED.slot_range,
        event_type = EXCLUDED.event_type,
        is_hard_block = EXCLUDED.is_hard_block,
        title = EXCLUDED.title;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;
-- ---------------------------------------------------------------------------
-- 6. Trigger function: sync clinical_sessions → busy_slots
--    Only inserts if no calendar_event already covers this time range.
--    This prevents conflicts when create_session_with_calendar creates both.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_clinical_session_to_busy_slots()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_end_time timestamptz;
  v_has_calendar_event boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.busy_slots
    WHERE source_type = 'clinical_session' AND source_id = OLD.id;
    RETURN OLD;
  END IF;

  v_end_time := NEW.start_time + (COALESCE(NEW.duration_minutes, 50) || ' minutes')::interval;

  -- Check if a calendar_event already covers this exact slot
  SELECT EXISTS (
    SELECT 1 FROM public.busy_slots bs
    WHERE bs.psychologist_id = NEW.psychologist_id
      AND bs.source_type = 'calendar_event'
      AND bs.slot_range && tstzrange(NEW.start_time, v_end_time, '[)')
      AND bs.is_hard_block = true
  ) INTO v_has_calendar_event;

  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.status::text, 'scheduled') NOT IN ('cancelled')
       AND NOT v_has_calendar_event THEN
      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        NEW.psychologist_id,
        tstzrange(NEW.start_time, v_end_time, '[)'),
        'clinical_session',
        NEW.id,
        'session',
        true,
        COALESCE(NEW.snapshot_service_name, 'Sessão')
      )
      ON CONFLICT (source_type, source_id) DO UPDATE SET
        psychologist_id = EXCLUDED.psychologist_id,
        slot_range = EXCLUDED.slot_range,
        is_hard_block = EXCLUDED.is_hard_block,
        title = EXCLUDED.title;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF COALESCE(NEW.status::text, 'scheduled') = 'cancelled' THEN
      DELETE FROM public.busy_slots
      WHERE source_type = 'clinical_session' AND source_id = NEW.id;
    ELSIF NOT v_has_calendar_event THEN
      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        NEW.psychologist_id,
        tstzrange(NEW.start_time, v_end_time, '[)'),
        'clinical_session',
        NEW.id,
        'session',
        true,
        COALESCE(NEW.snapshot_service_name, 'Sessão')
      )
      ON CONFLICT (source_type, source_id) DO UPDATE SET
        psychologist_id = EXCLUDED.psychologist_id,
        slot_range = EXCLUDED.slot_range,
        is_hard_block = EXCLUDED.is_hard_block,
        title = EXCLUDED.title;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;
-- ---------------------------------------------------------------------------
-- 7. Create triggers on source tables
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_calendar_event_busy_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.calendar_events
  FOR EACH ROW EXECUTE FUNCTION public.sync_calendar_event_to_busy_slots();
CREATE TRIGGER trg_clinical_session_busy_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.clinical_sessions
  FOR EACH ROW EXECUTE FUNCTION public.sync_clinical_session_to_busy_slots();
-- ---------------------------------------------------------------------------
-- 8. get_net_availability() — Core availability function
--
-- Returns available slots for a psychologist within a date range.
-- Steps:
--   1. Generate candidate slots from psychologist_availability (weekly config)
--   2. Apply availability_exceptions (add/remove slots for specific dates)
--   3. Subtract all busy_slots (events, sessions, blocks)
--   4. Return remaining free intervals as discrete slots
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_net_availability(
  p_psychologist_id uuid,
  p_start_date date,
  p_end_date date,
  p_slot_duration_minutes integer DEFAULT 50,
  p_timezone text DEFAULT 'America/Sao_Paulo'
)
RETURNS TABLE (
  slot_start timestamptz,
  slot_end timestamptz,
  duration_minutes integer,
  day_of_week integer,
  delivery_mode public.delivery_mode
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_date date;
  v_dow integer;
  v_range_start timestamptz;
  v_range_end timestamptz;
BEGIN
  -- Validate inputs
  IF p_end_date < p_start_date THEN
    RAISE EXCEPTION 'end_date must be >= start_date';
  END IF;
  IF p_end_date - p_start_date > 90 THEN
    RAISE EXCEPTION 'Date range cannot exceed 90 days';
  END IF;
  IF p_slot_duration_minutes < 15 OR p_slot_duration_minutes > 240 THEN
    RAISE EXCEPTION 'Slot duration must be between 15 and 240 minutes';
  END IF;

  -- Compute the full timestamptz range for the query window
  v_range_start := (p_start_date::text || ' 00:00:00')::timestamp AT TIME ZONE p_timezone;
  v_range_end := ((p_end_date + 1)::text || ' 00:00:00')::timestamp AT TIME ZONE p_timezone;

  RETURN QUERY
  WITH
  -- Step 1: Generate availability windows from weekly config
  availability_windows AS (
    SELECT
      d.day_date,
      EXTRACT(DOW FROM d.day_date)::integer AS dow,
      (d.day_date::text || ' ' || pa.start_time::text)::timestamp AT TIME ZONE p_timezone AS win_start,
      (d.day_date::text || ' ' || pa.end_time::text)::timestamp AT TIME ZONE p_timezone AS win_end,
      pa.delivery_mode AS dm
    FROM
      generate_series(p_start_date, p_end_date, '1 day'::interval) AS d(day_date),
      public.psychologist_availability pa
    WHERE
      pa.psychologist_id = p_psychologist_id
      AND pa.is_active = true
      AND pa.day_of_week = EXTRACT(DOW FROM d.day_date)::integer
      AND (pa.effective_start IS NULL OR d.day_date >= pa.effective_start)
      AND (pa.effective_end IS NULL OR d.day_date <= pa.effective_end)
  ),

  -- Step 2: Apply availability exceptions
  -- Remove days marked unavailable; add/replace windows for available exceptions
  exception_overrides AS (
    SELECT
      ae.exception_date,
      ae.is_available,
      ae.start_time,
      ae.end_time
    FROM public.availability_exceptions ae
    WHERE
      ae.psychologist_id = p_psychologist_id
      AND ae.exception_date BETWEEN p_start_date AND p_end_date
  ),

  -- Merge: remove windows on unavailable exception days,
  -- keep exception windows on available exception days
  effective_windows AS (
    -- Regular availability on non-exception days
    SELECT aw.win_start, aw.win_end, aw.dm, aw.dow
    FROM availability_windows aw
    WHERE NOT EXISTS (
      SELECT 1 FROM exception_overrides eo
      WHERE eo.exception_date = aw.day_date::date
    )

    UNION ALL

    -- Exception days with custom availability
    SELECT
      (eo.exception_date::text || ' ' || eo.start_time::text)::timestamp AT TIME ZONE p_timezone,
      (eo.exception_date::text || ' ' || eo.end_time::text)::timestamp AT TIME ZONE p_timezone,
      'hybrid'::public.delivery_mode,
      EXTRACT(DOW FROM eo.exception_date)::integer
    FROM exception_overrides eo
    WHERE eo.is_available = true
      AND eo.start_time IS NOT NULL
      AND eo.end_time IS NOT NULL
  ),

  -- Step 3: Generate discrete slots within each effective window
  candidate_slots AS (
    SELECT
      ew.win_start + (s.n * (p_slot_duration_minutes || ' minutes')::interval) AS cs_start,
      ew.win_start + ((s.n + 1) * (p_slot_duration_minutes || ' minutes')::interval) AS cs_end,
      ew.dm AS cs_dm,
      ew.dow AS cs_dow
    FROM effective_windows ew
    CROSS JOIN LATERAL generate_series(
      0,
      (EXTRACT(EPOCH FROM (ew.win_end - ew.win_start)) / (p_slot_duration_minutes * 60))::integer - 1
    ) AS s(n)
    WHERE ew.win_start + ((s.n + 1) * (p_slot_duration_minutes || ' minutes')::interval) <= ew.win_end
  ),

  -- Step 4: Subtract busy slots using range overlap
  free_slots AS (
    SELECT cs.cs_start, cs.cs_end, cs.cs_dm, cs.cs_dow
    FROM candidate_slots cs
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.busy_slots bs
      WHERE bs.psychologist_id = p_psychologist_id
        AND bs.slot_range && tstzrange(cs.cs_start, cs.cs_end, '[)')
    )
  )

  SELECT
    fs.cs_start,
    fs.cs_end,
    p_slot_duration_minutes,
    fs.cs_dow,
    fs.cs_dm
  FROM free_slots fs
  WHERE fs.cs_start >= v_range_start
    AND fs.cs_end <= v_range_end
    AND fs.cs_start >= now()
  ORDER BY fs.cs_start;
END;
$$;
-- ---------------------------------------------------------------------------
-- 9. book_appointment() — Atomic booking RPC
--
-- Validates slot availability and creates both calendar_event and
-- clinical_session in a single transaction. The exclusion constraint
-- on busy_slots is the final guard against double-booking.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.book_appointment(
  p_psychologist_id uuid,
  p_patient_client_id uuid,
  p_start_time timestamptz,
  p_duration_minutes integer DEFAULT 50,
  p_service_id uuid DEFAULT NULL,
  p_location_id uuid DEFAULT NULL,
  p_timezone text DEFAULT 'America/Sao_Paulo',
  p_title text DEFAULT 'Sessão'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_end_time timestamptz;
  v_event_id uuid;
  v_session_id uuid;
  v_conflict_count integer;
  v_service_name text;
  v_service_price integer;
BEGIN
  v_end_time := p_start_time + (p_duration_minutes || ' minutes')::interval;

  -- Input validation
  IF p_start_time < now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'SLOT_IN_PAST',
      'message', 'Cannot book a slot in the past'
    );
  END IF;

  IF p_duration_minutes < 15 OR p_duration_minutes > 240 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INVALID_DURATION',
      'message', 'Duration must be between 15 and 240 minutes'
    );
  END IF;

  -- Advisory pre-check: is the slot currently free?
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.busy_slots
  WHERE psychologist_id = p_psychologist_id
    AND slot_range && tstzrange(p_start_time, v_end_time, '[)')
    AND is_hard_block = true;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'SLOT_CONFLICT',
      'message', 'The selected time slot conflicts with an existing appointment or block'
    );
  END IF;

  -- Fetch service details if provided
  IF p_service_id IS NOT NULL THEN
    SELECT ps.name, ps.price_cents
    INTO v_service_name, v_service_price
    FROM public.psychologist_services ps
    WHERE ps.id = p_service_id AND ps.psychologist_id = p_psychologist_id;
  END IF;

  -- Create calendar event (trigger will sync to busy_slots → exclusion constraint fires here)
  BEGIN
    INSERT INTO public.calendar_events (
      psychologist_id,
      event_type,
      title,
      start_datetime,
      end_datetime,
      duration_minutes,
      timezone,
      status,
      source
    ) VALUES (
      p_psychologist_id,
      'session',
      COALESCE(p_title, 'Sessão'),
      p_start_time,
      v_end_time,
      p_duration_minutes,
      p_timezone,
      'scheduled',
      'fluri'
    )
    RETURNING id INTO v_event_id;
  EXCEPTION
    WHEN exclusion_violation THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'DOUBLE_BOOKING_PREVENTED',
        'message', 'Another booking was made for this time slot. Please select a different time.'
      );
  END;

  -- Create clinical session
  INSERT INTO public.clinical_sessions (
    psychologist_id,
    psychologist_client_id,
    start_time,
    duration_minutes,
    psychologist_service_id,
    location_id,
    snapshot_service_name,
    snapshot_price_cents,
    status,
    created_by
  ) VALUES (
    p_psychologist_id,
    p_patient_client_id,
    p_start_time,
    p_duration_minutes,
    p_service_id,
    p_location_id,
    v_service_name,
    v_service_price,
    'scheduled',
    auth.uid()
  )
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'event_id', v_event_id,
      'session_id', v_session_id,
      'start_time', p_start_time,
      'end_time', v_end_time,
      'duration_minutes', p_duration_minutes
    )
  );
END;
$$;
-- ---------------------------------------------------------------------------
-- 10. Backfill: populate busy_slots from existing calendar_events
--     Uses DO block to handle pre-existing overlaps in data gracefully
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_row RECORD;
  v_inserted integer := 0;
  v_skipped integer := 0;
BEGIN
  FOR v_row IN
    SELECT
      ce.psychologist_id,
      tstzrange(ce.start_datetime, ce.end_datetime, '[)') AS slot_range,
      'calendar_event'::text AS source_type,
      ce.id AS source_id,
      ce.event_type,
      ce.event_type IN ('session', 'block', 'supervision') AS is_hard_block,
      ce.title
    FROM public.calendar_events ce
    WHERE ce.status NOT IN ('cancelled', 'rescheduled')
    ORDER BY ce.created_at ASC
  LOOP
    BEGIN
      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        v_row.psychologist_id, v_row.slot_range, v_row.source_type, v_row.source_id,
        v_row.event_type, v_row.is_hard_block, v_row.title
      )
      ON CONFLICT (source_type, source_id) DO NOTHING;
      v_inserted := v_inserted + 1;
    EXCEPTION
      WHEN exclusion_violation THEN
        v_skipped := v_skipped + 1;
    END;
  END LOOP;
  RAISE NOTICE 'Backfill calendar_events: inserted=%, skipped=%', v_inserted, v_skipped;
END;
$$;
-- ---------------------------------------------------------------------------
-- 11. Backfill: populate busy_slots from clinical_sessions
--     Only for sessions that don't already have a covering calendar_event
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_row RECORD;
  v_inserted integer := 0;
  v_skipped integer := 0;
BEGIN
  FOR v_row IN
    SELECT
      cs.psychologist_id,
      tstzrange(cs.start_time, cs.start_time + (COALESCE(cs.duration_minutes, 50) || ' minutes')::interval, '[)') AS slot_range,
      'clinical_session'::text AS source_type,
      cs.id AS source_id,
      'session'::public.calendar_event_type AS event_type,
      true AS is_hard_block,
      COALESCE(cs.snapshot_service_name, 'Sessão') AS title
    FROM public.clinical_sessions cs
    WHERE COALESCE(cs.status::text, 'scheduled') != 'cancelled'
    ORDER BY cs.created_at ASC
  LOOP
    BEGIN
      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        v_row.psychologist_id, v_row.slot_range, v_row.source_type, v_row.source_id,
        v_row.event_type, v_row.is_hard_block, v_row.title
      )
      ON CONFLICT (source_type, source_id) DO NOTHING;
      v_inserted := v_inserted + 1;
    EXCEPTION
      WHEN exclusion_violation THEN
        v_skipped := v_skipped + 1;
    END;
  END LOOP;
  RAISE NOTICE 'Backfill clinical_sessions: inserted=%, skipped=%', v_inserted, v_skipped;
END;
$$;
-- ---------------------------------------------------------------------------
-- 12. Helper function: check_slot_available()
--     Lightweight pre-check for frontend use
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_slot_available(
  p_psychologist_id uuid,
  p_start_time timestamptz,
  p_end_time timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1
    FROM public.busy_slots
    WHERE psychologist_id = p_psychologist_id
      AND slot_range && tstzrange(p_start_time, p_end_time, '[)')
      AND is_hard_block = true
  );
$$;
-- ---------------------------------------------------------------------------
-- 13. Grant execute permissions on functions
-- ---------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.get_net_availability(uuid, date, date, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_net_availability(uuid, date, date, integer, text) TO anon;
GRANT EXECUTE ON FUNCTION public.book_appointment(uuid, uuid, timestamptz, integer, uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_slot_available(uuid, timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_slot_available(uuid, timestamptz, timestamptz) TO anon;
