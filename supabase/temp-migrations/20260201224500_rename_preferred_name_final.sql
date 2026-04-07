-- Rename preferred_name columns to display_name for psychologists and clients
BEGIN;
-- 1. Table: public.psychologists
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'psychologists' AND column_name = 'preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'psychologists' AND column_name = 'display_name') THEN
      ALTER TABLE public.psychologists RENAME COLUMN preferred_name TO display_name;
    ELSE
      -- Merge if necessary or drop redundant
      ALTER TABLE public.psychologists DROP COLUMN preferred_name;
    END IF;
  END IF;
END $$;
-- 2. Table: public.psychologist_clients
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'psychologist_clients' AND column_name = 'manual_preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'psychologist_clients' AND column_name = 'manual_display_name') THEN
      ALTER TABLE public.psychologist_clients RENAME COLUMN manual_preferred_name TO manual_display_name;
    ELSE
      ALTER TABLE public.psychologist_clients DROP COLUMN manual_preferred_name;
    END IF;
  END IF;
END $$;
COMMIT;
