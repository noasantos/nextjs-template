-- Fix concurrency and overlap issues between clinical_sessions and calendar_events in busy_slots
-- The goal is to make the synchronization idempotent and prevent exclusion constraint violations
-- during create_session_with_calendar which inserts into both tables.

-- 1. Update calendar_event trigger to handle potential session slot cleanup
CREATE OR REPLACE FUNCTION public.sync_calendar_event_to_busy_slots()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_slot_range tstzrange;
  v_is_hard_block boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.busy_slots
    WHERE source_type = 'calendar_event' AND source_id = OLD.id;
    RETURN OLD;
  END IF;

  v_slot_range := tstzrange(NEW.start_datetime, NEW.end_datetime, '[)');
  v_is_hard_block := NEW.event_type IN ('session', 'block', 'supervision');

  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.status IN ('cancelled', 'rescheduled') THEN
      DELETE FROM public.busy_slots
      WHERE source_type = 'calendar_event' AND source_id = NEW.id;
    ELSE
      -- CRITICAL FIX: If we are inserting a session event, first remove any clinical_session slot 
      -- that might have been created by a previous step in the same transaction 
      -- (common in create_session_with_calendar RPC)
      IF NEW.event_type = 'session' THEN
        DELETE FROM public.busy_slots
        WHERE psychologist_id = NEW.psychologist_id
          AND slot_range = v_slot_range
          AND source_type = 'clinical_session';
      END IF;

      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        NEW.psychologist_id,
        v_slot_range,
        'calendar_event',
        NEW.id,
        NEW.event_type,
        v_is_hard_block,
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
-- 2. Update clinical_session trigger to be more defensive
CREATE OR REPLACE FUNCTION public.sync_clinical_session_to_busy_slots()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_end_time timestamptz;
  v_slot_range tstzrange;
  v_has_calendar_event boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.busy_slots
    WHERE source_type = 'clinical_session' AND source_id = OLD.id;
    RETURN OLD;
  END IF;

  v_end_time := NEW.start_time + (COALESCE(NEW.duration_minutes, 50) || ' minutes')::interval;
  v_slot_range := tstzrange(NEW.start_time, v_end_time, '[)');

  -- Check if a calendar_event already covers this exact slot
  SELECT EXISTS (
    SELECT 1 FROM public.busy_slots bs
    WHERE bs.psychologist_id = NEW.psychologist_id
      AND bs.slot_range && v_slot_range
      AND bs.source_type = 'calendar_event'
      AND bs.is_hard_block = true
  ) INTO v_has_calendar_event;

  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF COALESCE(NEW.status::text, 'scheduled') = 'cancelled' THEN
      DELETE FROM public.busy_slots
      WHERE source_type = 'clinical_session' AND source_id = NEW.id;
    ELSIF NOT v_has_calendar_event THEN
      INSERT INTO public.busy_slots (
        psychologist_id, slot_range, source_type, source_id,
        event_type, is_hard_block, title
      ) VALUES (
        NEW.psychologist_id,
        v_slot_range,
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
    ELSE
      -- If there is a calendar event, make sure we don't have a stray session slot
      DELETE FROM public.busy_slots
      WHERE source_type = 'clinical_session' AND source_id = NEW.id;
    END IF;
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;
