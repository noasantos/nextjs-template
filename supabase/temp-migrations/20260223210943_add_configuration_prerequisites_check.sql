-- migration-created-via: pnpm supabase:migration:new
-- RPC function to validate configuration prerequisites before completing Phase 2

CREATE OR REPLACE FUNCTION public.check_configuration_prerequisites(p_psychologist_id UUID)
RETURNS TABLE (
  has_services BOOLEAN,
  has_locations BOOLEAN,
  has_online_delivery BOOLEAN,
  has_availability BOOLEAN,
  all_prerequisites_met BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN QUERY
  WITH 
  services_check AS (
    SELECT EXISTS (
      SELECT 1 FROM psychologist_services 
      WHERE psychologist_id = p_psychologist_id AND is_active = true
    ) AS has_services
  ),
  locations_check AS (
    SELECT EXISTS (
      SELECT 1 FROM public_locations 
      WHERE psychologist_id = p_psychologist_id AND is_active = true
    ) AS has_locations
  ),
  online_check AS (
    SELECT EXISTS (
      SELECT 1 FROM psychologist_weekly_schedules 
      WHERE psychologist_id = p_psychologist_id 
        AND delivery_mode IN ('telehealth', 'hybrid') 
        AND is_active = true
    ) AS has_online_delivery
  ),
  availability_check AS (
    SELECT EXISTS (
      SELECT 1 FROM psychologist_weekly_schedules 
      WHERE psychologist_id = p_psychologist_id AND is_active = true
    ) AS has_availability
  )
  SELECT 
    s.has_services,
    l.has_locations,
    o.has_online_delivery,
    a.has_availability,
    (s.has_services AND (l.has_locations OR o.has_online_delivery) AND a.has_availability) AS all_prerequisites_met
  FROM services_check s, locations_check l, online_check o, availability_check a;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.check_configuration_prerequisites(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_configuration_prerequisites(UUID) TO service_role;

-- Add documentation
COMMENT ON FUNCTION public.check_configuration_prerequisites(UUID) IS 
  'Validates that a psychologist has met all prerequisites before completing Phase 2 onboarding:
   - At least 1 active service
   - At least 1 active location OR online delivery enabled (telehealth/hybrid in schedules)
   - At least 1 active availability slot';
