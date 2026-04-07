CREATE OR REPLACE FUNCTION public.handle_session_update_charge()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('app.fluri.skip_charge_triggers', true) = 'on' THEN
    RETURN NEW;
  END IF;

  IF NEW.start_time IS DISTINCT FROM OLD.start_time
     OR NEW.snapshot_price_cents IS DISTINCT FROM OLD.snapshot_price_cents
     OR NEW.snapshot_service_name IS DISTINCT FROM OLD.snapshot_service_name
     OR NEW.status IS DISTINCT FROM OLD.status THEN
    PERFORM public.create_session_charge_if_due(
      NEW.id,
      NEW.psychologist_id,
      7,
      false,
      format('charge:session:%s:v1', NEW.id)
    );
  END IF;

  RETURN NEW;
END;
$$;
