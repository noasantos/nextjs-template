-- migration-created-via: pnpm supabase:migration:new

-- Clear image_path for all clinical activities as they don't have images yet
-- This ensures the UI falls back to the default placeholder instead of trying to load non-existent images
UPDATE public.catalog_clinical_activities
SET image_path = NULL;
