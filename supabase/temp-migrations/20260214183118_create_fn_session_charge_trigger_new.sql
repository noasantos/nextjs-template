CREATE OR REPLACE FUNCTION public.handle_new_session_charge()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('app.fluri.skip_charge_triggers', true) = 'on' THEN
    RETURN NEW;
  END IF;

  PERFORM public.create_session_charge_if_due(
    NEW.id,
    NEW.psychologist_id,
    7,
    false,
    format('charge:session:%s:v1', NEW.id)
  );

  RETURN NEW;
END;
$$;
