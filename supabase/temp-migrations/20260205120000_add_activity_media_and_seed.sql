-- Add media paths for activities
ALTER TABLE IF EXISTS public.clinical_activities_catalog
  ADD COLUMN IF NOT EXISTS image_path text,
  ADD COLUMN IF NOT EXISTS pdf_path text;

-- Create storage buckets for activity assets
-- Note: Bucket data is now seeded via supabase/seed.sql (storage buckets section)
-- This insert remains for backward compatibility during migration transition
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('activity-images', 'activity-images', true),
  ('activity-pdfs', 'activity-pdfs', false)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = EXCLUDED.public;

-- Storage policies for activity assets
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'activity_images_read'
  ) THEN
    CREATE POLICY "activity_images_read"
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'activity_pdfs_read'
  ) THEN
    CREATE POLICY "activity_pdfs_read"
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (bucket_id = 'activity-pdfs');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'activity_images_write'
  ) THEN
    CREATE POLICY "activity_images_write"
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'activity_pdfs_write'
  ) THEN
    CREATE POLICY "activity_pdfs_write"
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (bucket_id = 'activity-pdfs');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'activity_images_update'
  ) THEN
    CREATE POLICY "activity_images_update"
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (bucket_id = 'activity-images')
      WITH CHECK (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'activity_pdfs_update'
  ) THEN
    CREATE POLICY "activity_pdfs_update"
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (bucket_id = 'activity-pdfs')
      WITH CHECK (bucket_id = 'activity-pdfs');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'activity_images_delete'
  ) THEN
    CREATE POLICY "activity_images_delete"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'activity_pdfs_delete'
  ) THEN
    CREATE POLICY "activity_pdfs_delete"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (bucket_id = 'activity-pdfs');
  END IF;
END $$;

-- Note: Clinical activities seed data has been moved to supabase/seed.sql (clinical activities section)
-- This migration now only handles schema changes (columns and storage policies)
