-- Fix compound first names display logic
-- The previous logic was failing to correctly identify compound names or recompute them for existing patients.

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

  -- Split base_name by spaces. If it has 2 or more parts, it's a compound name.
  base_parts := regexp_split_to_array(normalized_base, '\s+');
  IF COALESCE(array_length(base_parts, 1), 0) >= 2 THEN
    RETURN normalized_base;
  END IF;

  -- If it's a simple name and has a surname, take the last word of the surname.
  IF normalized_surname IS NULL THEN
    RETURN normalized_base;
  END IF;

  surname_parts := regexp_split_to_array(normalized_surname, '\s+');
  surname_last_word := surname_parts[COALESCE(array_length(surname_parts, 1), 1)];

  IF surname_last_word IS NULL OR btrim(surname_last_word) = '' THEN
    RETURN normalized_base;
  END IF;

  RETURN normalized_base || ' ' || surname_last_word;
END;
$$;
-- Force recompute for ALL active patients to ensure Rafael Augusto (and others) are fixed.
UPDATE public.psychologist_clients
SET manual_display_name = public.compute_short_display_name(
  COALESCE(NULLIF(btrim(manual_preferred_name), ''), manual_first_name),
  manual_last_name
)
WHERE status = 'active'
  AND (manual_first_name IS NOT NULL OR manual_preferred_name IS NOT NULL);
