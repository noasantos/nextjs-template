-- Add manual_patient_origin to psychologist_clients (e.g. referral source / origin)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'psychologist_clients'
          AND column_name = 'manual_patient_origin'
    ) THEN
        ALTER TABLE public.psychologist_clients
        ADD COLUMN manual_patient_origin TEXT;
    END IF;
END $$;
