-- Ensure critical FK relationships exist for PostgREST nested selects used by the app.
-- These relationships are required by joins in:
-- - psychologist_clinical_sessions -> public_locations
-- - psychologist_financial_entries -> financial_categories
-- - psychologist_services -> reference_values

-------------------------------------------------------------------------------
-- 1. psychologist_clinical_sessions.location_id -> public_locations.id
-------------------------------------------------------------------------------

UPDATE public.psychologist_clinical_sessions pcs
SET location_id = NULL
WHERE pcs.location_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.public_locations pl
    WHERE pl.id = pcs.location_id
  );
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'clinical_sessions_location_id_fkey'
      AND conrelid = 'public.psychologist_clinical_sessions'::regclass
  ) THEN
    ALTER TABLE public.psychologist_clinical_sessions
      ADD CONSTRAINT clinical_sessions_location_id_fkey
      FOREIGN KEY (location_id)
      REFERENCES public.public_locations(id)
      ON DELETE SET NULL;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_psychologist_clinical_sessions_location_id
  ON public.psychologist_clinical_sessions(location_id);
-------------------------------------------------------------------------------
-- 2. psychologist_financial_entries.category_id -> financial_categories.id
-------------------------------------------------------------------------------

UPDATE public.psychologist_financial_entries pfe
SET category_id = NULL
WHERE pfe.category_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.financial_categories fc
    WHERE fc.id = pfe.category_id
  );
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'psychologist_financial_entries_category_id_fkey'
      AND conrelid = 'public.psychologist_financial_entries'::regclass
  ) THEN
    ALTER TABLE public.psychologist_financial_entries
      ADD CONSTRAINT psychologist_financial_entries_category_id_fkey
      FOREIGN KEY (category_id)
      REFERENCES public.financial_categories(id)
      ON DELETE SET NULL;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_psychologist_financial_entries_category_id
  ON public.psychologist_financial_entries(category_id);
-------------------------------------------------------------------------------
-- 3. psychologist_services.catalog_id -> reference_values.id
-------------------------------------------------------------------------------

UPDATE public.psychologist_services ps
SET catalog_id = NULL
WHERE ps.catalog_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.reference_values rv
    WHERE rv.id = ps.catalog_id
  );
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'psychologist_services_catalog_id_fkey'
      AND conrelid = 'public.psychologist_services'::regclass
  ) THEN
    ALTER TABLE public.psychologist_services
      ADD CONSTRAINT psychologist_services_catalog_id_fkey
      FOREIGN KEY (catalog_id)
      REFERENCES public.reference_values(id)
      ON DELETE SET NULL;
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS psychologist_services_catalog_id_idx
  ON public.psychologist_services(catalog_id);
