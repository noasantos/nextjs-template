-- Add generated full_name column to patients table
ALTER TABLE public.patients 
ADD COLUMN IF NOT EXISTS full_name TEXT GENERATED ALWAYS AS (trim(first_name || ' ' || last_name)) STORED;
-- Add index on full_name for search performance
CREATE INDEX IF NOT EXISTS idx_patients_full_name ON public.patients(full_name);
