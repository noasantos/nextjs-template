GRANT EXECUTE ON FUNCTION public.process_pending_session_billing(
  integer, integer
) TO authenticated, service_role;
