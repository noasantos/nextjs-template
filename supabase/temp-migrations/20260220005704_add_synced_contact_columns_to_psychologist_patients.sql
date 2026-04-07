-- Align local schema with production/runtime expectations.
-- Several query paths and generated Database types expect these columns.

DO $$
BEGIN
  -- Current canonical table name
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'psychologist_patients'
  ) THEN
    ALTER TABLE public.psychologist_patients
      ADD COLUMN IF NOT EXISTS synced_phone TEXT,
      ADD COLUMN IF NOT EXISTS synced_email TEXT;

    COMMENT ON COLUMN public.psychologist_patients.synced_phone IS
      'Phone synced from linked patient identity/provider when available.';
    COMMENT ON COLUMN public.psychologist_patients.synced_email IS
      'Email synced from linked patient identity/provider when available.';
  END IF;

  -- Backward compatibility for environments that still use the pre-rename table
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'psychologist_clients'
  ) THEN
    ALTER TABLE public.psychologist_clients
      ADD COLUMN IF NOT EXISTS synced_phone TEXT,
      ADD COLUMN IF NOT EXISTS synced_email TEXT;

    COMMENT ON COLUMN public.psychologist_clients.synced_phone IS
      'Phone synced from linked patient identity/provider when available.';
    COMMENT ON COLUMN public.psychologist_clients.synced_email IS
      'Email synced from linked patient identity/provider when available.';
  END IF;
END;
$$;
-- Ensure PostgREST immediately sees the new columns for !select usage.
NOTIFY pgrst, 'reload schema';
