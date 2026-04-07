-- Ensure CPF is stored in the core psychologist identity table.
ALTER TABLE public.user_psychologists
ADD COLUMN IF NOT EXISTS cpf TEXT;
-- Backfill CPF from public_profiles only when that table/column exists.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'public_profiles'
      AND column_name = 'cpf'
  ) THEN
    UPDATE public.user_psychologists up
    SET cpf = pp.cpf
    FROM public.public_profiles pp
    WHERE up.id = pp.id
      AND up.cpf IS NULL
      AND pp.cpf IS NOT NULL;
  END IF;
END $$;
