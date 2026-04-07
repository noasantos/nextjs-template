-- supabase/migrations/20260208161000_add_audit_monitor_rpcs.sql

-- Detect high volume service role usage
CREATE OR REPLACE FUNCTION public.detect_high_volume_service_role_usage(
  threshold INTEGER,
  window_minutes INTEGER
)
RETURNS TABLE (
  source TEXT,
  operation_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sra.source,
    COUNT(*) as operation_count
  FROM 
    public.service_role_audit_log sra
  WHERE 
    sra.created_at > NOW() - (window_minutes || ' minutes')::INTERVAL
  GROUP BY 
    sra.source
  HAVING 
    COUNT(*) > threshold;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Detect unusual table access
CREATE OR REPLACE FUNCTION public.detect_unusual_table_access(
  whitelisted_tables TEXT[]
)
RETURNS TABLE (
  source TEXT,
  table_name TEXT,
  access_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sra.source,
    sra.table_name,
    COUNT(*) as access_count
  FROM 
    public.service_role_audit_log sra
  WHERE 
    sra.table_name IS NOT NULL
    AND NOT (sra.table_name = ANY(whitelisted_tables))
    AND sra.created_at > NOW() - INTERVAL '24 hours'
  GROUP BY 
    sra.source, sra.table_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Detect suspicious error patterns
CREATE OR REPLACE FUNCTION public.detect_suspicious_error_patterns()
RETURNS TABLE (
  source TEXT,
  error_message TEXT,
  error_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sra.source,
    sra.error_message,
    COUNT(*) as error_count
  FROM 
    public.service_role_audit_log sra
  WHERE 
    sra.success = false
    AND sra.created_at > NOW() - INTERVAL '1 hour'
  GROUP BY 
    sra.source, sra.error_message
  HAVING 
    COUNT(*) > 10; -- threshold for repeated errors
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
