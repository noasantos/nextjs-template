-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-03-03T00:33:34Z

-- Fix: update_patient_session_stats trigger function referenced
-- psychologist_clients (old) instead of psychologist_patients (new)
-- and psychologist_client_id instead of psychologist_patient_id.
CREATE OR REPLACE FUNCTION public.update_patient_session_stats()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    UPDATE public.psychologist_patients
    SET 
      last_session_date = NEW.start_time::date,
      total_sessions_count = COALESCE(total_sessions_count, 0) + 1,
      updated_at = NOW()
    WHERE id = NEW.psychologist_patient_id;
  END IF;
  RETURN NEW;
END;
$$;
