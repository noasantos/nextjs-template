-- Add missing foreign key between clinical_sessions and psychologist_services
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_name = 'clinical_sessions_psychologist_service_id_fkey'
        AND table_name = 'clinical_sessions'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.clinical_sessions
        ADD CONSTRAINT clinical_sessions_psychologist_service_id_fkey
        FOREIGN KEY (psychologist_service_id)
        REFERENCES public.psychologist_services(id)
        ON DELETE SET NULL;
    END IF;
END $$;
-- Add index for the foreign key to improve performance
CREATE INDEX IF NOT EXISTS idx_clinical_sessions_psychologist_service_id
ON public.clinical_sessions(psychologist_service_id);
