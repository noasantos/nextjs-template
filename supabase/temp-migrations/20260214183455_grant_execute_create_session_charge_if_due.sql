GRANT EXECUTE ON FUNCTION public.create_session_charge_if_due(
  uuid, uuid, integer, boolean, text
) TO authenticated, service_role;
