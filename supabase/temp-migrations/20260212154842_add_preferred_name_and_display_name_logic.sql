BEGIN;
-- Reintroduce preferred name fields for patient identity handling.
ALTER TABLE public.patients
  ADD COLUMN IF NOT EXISTS preferred_name TEXT;
ALTER TABLE public.psychologist_clients
  ADD COLUMN IF NOT EXISTS manual_preferred_name TEXT;
-- Preserve existing display_name input as preferred_name during transition.
UPDATE public.patients
SET preferred_name = display_name
WHERE preferred_name IS NULL
  AND display_name IS NOT NULL
  AND btrim(display_name) <> '';
UPDATE public.psychologist_clients
SET manual_preferred_name = manual_display_name
WHERE manual_preferred_name IS NULL
  AND manual_display_name IS NOT NULL
  AND btrim(manual_display_name) <> '';
-- Shared helper: base display from preferred_name (if present) or legal first name.
CREATE OR REPLACE FUNCTION public.compute_short_display_name(
  base_name TEXT,
  surname TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  normalized_base TEXT;
  normalized_surname TEXT;
  base_parts TEXT[];
  surname_parts TEXT[];
  surname_last_word TEXT;
BEGIN
  normalized_base := NULLIF(btrim(base_name), '');
  normalized_surname := NULLIF(btrim(surname), '');

  IF normalized_base IS NULL THEN
    RETURN NULL;
  END IF;

  base_parts := regexp_split_to_array(normalized_base, '\\s+');
  IF COALESCE(array_length(base_parts, 1), 0) >= 2 THEN
    RETURN normalized_base;
  END IF;

  IF normalized_surname IS NULL THEN
    RETURN normalized_base;
  END IF;

  surname_parts := regexp_split_to_array(normalized_surname, '\\s+');
  surname_last_word := surname_parts[COALESCE(array_length(surname_parts, 1), 1)];

  IF surname_last_word IS NULL OR btrim(surname_last_word) = '' THEN
    RETURN normalized_base;
  END IF;

  RETURN normalized_base || ' ' || surname_last_word;
END;
$$;
CREATE OR REPLACE FUNCTION public.generate_patient_display_name()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  source_name TEXT;
BEGIN
  source_name := COALESCE(NULLIF(btrim(NEW.manual_preferred_name), ''), NEW.manual_first_name);
  NEW.manual_display_name := public.compute_short_display_name(source_name, NEW.manual_last_name);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trigger_generate_display_name ON public.psychologist_clients;
CREATE TRIGGER trigger_generate_display_name
BEFORE INSERT OR UPDATE OF manual_first_name, manual_last_name, manual_preferred_name
ON public.psychologist_clients
FOR EACH ROW
EXECUTE FUNCTION public.generate_patient_display_name();
CREATE OR REPLACE FUNCTION public.generate_public_patient_display_name()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  source_name TEXT;
BEGIN
  source_name := COALESCE(NULLIF(btrim(NEW.preferred_name), ''), NEW.first_name);
  NEW.display_name := public.compute_short_display_name(source_name, NEW.last_name);
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trigger_generate_public_patient_display_name ON public.patients;
CREATE TRIGGER trigger_generate_public_patient_display_name
BEFORE INSERT OR UPDATE OF first_name, last_name, preferred_name
ON public.patients
FOR EACH ROW
EXECUTE FUNCTION public.generate_public_patient_display_name();
-- Recompute display names to enforce new priority/rules.
UPDATE public.psychologist_clients
SET manual_display_name = public.compute_short_display_name(
  COALESCE(NULLIF(btrim(manual_preferred_name), ''), manual_first_name),
  manual_last_name
)
WHERE manual_first_name IS NOT NULL
   OR manual_preferred_name IS NOT NULL;
UPDATE public.patients
SET display_name = public.compute_short_display_name(
  COALESCE(NULLIF(btrim(preferred_name), ''), first_name),
  last_name
)
WHERE first_name IS NOT NULL
   OR preferred_name IS NOT NULL;
COMMIT;
