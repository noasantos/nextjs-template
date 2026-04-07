-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:23:26Z

SET check_function_bodies = false;

-- image_path / pdf_path live on catalog_clinical_activities from product migrations
-- (avoid ADD COLUMN IF NOT EXISTS here — Postgres emits NOTICE 42701 when skipped)

-- Buckets + policies (from legacy migrations; idempotent)
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('activity-images', 'activity-images', true),
  ('activity-pdfs', 'activity-pdfs', false)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = EXCLUDED.public;

INSERT INTO storage.buckets (id, name, public)
VALUES ('patient-documents', 'patient-documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;

UPDATE storage.buckets SET public = false WHERE id = 'patient-documents';

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profiles',
  'profiles',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = NOW();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'activity_images_read'
  ) THEN
    CREATE POLICY "activity_images_read" ON storage.objects FOR SELECT TO authenticated
      USING (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'activity_pdfs_read'
  ) THEN
    CREATE POLICY "activity_pdfs_read" ON storage.objects FOR SELECT TO authenticated
      USING (bucket_id = 'activity-pdfs');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'activity_images_write'
  ) THEN
    CREATE POLICY "activity_images_write" ON storage.objects FOR INSERT TO authenticated
      WITH CHECK (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'activity_pdfs_write'
  ) THEN
    CREATE POLICY "activity_pdfs_write" ON storage.objects FOR INSERT TO authenticated
      WITH CHECK (bucket_id = 'activity-pdfs');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'activity_images_update'
  ) THEN
    CREATE POLICY "activity_images_update" ON storage.objects FOR UPDATE TO authenticated
      USING (bucket_id = 'activity-images') WITH CHECK (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'activity_pdfs_update'
  ) THEN
    CREATE POLICY "activity_pdfs_update" ON storage.objects FOR UPDATE TO authenticated
      USING (bucket_id = 'activity-pdfs') WITH CHECK (bucket_id = 'activity-pdfs');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'activity_images_delete'
  ) THEN
    CREATE POLICY "activity_images_delete" ON storage.objects FOR DELETE TO authenticated
      USING (bucket_id = 'activity-images');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'activity_pdfs_delete'
  ) THEN
    CREATE POLICY "activity_pdfs_delete" ON storage.objects FOR DELETE TO authenticated
      USING (bucket_id = 'activity-pdfs');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can read own documents'
  ) THEN
    CREATE POLICY "Users can read own documents" ON storage.objects FOR SELECT TO authenticated
      USING (bucket_id = 'patient-documents' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can upload to own folder'
  ) THEN
    CREATE POLICY "Users can upload to own folder" ON storage.objects FOR INSERT TO authenticated
      WITH CHECK (bucket_id = 'patient-documents' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can delete own documents'
  ) THEN
    CREATE POLICY "Users can delete own documents" ON storage.objects FOR DELETE TO authenticated
      USING (bucket_id = 'patient-documents' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.check_file_size()
RETURNS TRIGGER AS $tr$
BEGIN
  IF NEW.bucket_id = 'patient-documents'
     AND COALESCE((NEW.metadata->>'size')::bigint, 0) > 10485760 THEN
    RAISE EXCEPTION 'File too large. Maximum size is 10MB';
  END IF;
  RETURN NEW;
END;
$tr$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'storage'
      AND c.relname = 'objects'
      AND NOT t.tgisinternal
      AND t.tgname = 'check_file_size_trigger'
  ) THEN
    EXECUTE 'DROP TRIGGER check_file_size_trigger ON storage.objects';
  END IF;
END $$;
CREATE TRIGGER check_file_size_trigger
  BEFORE INSERT ON storage.objects
  FOR EACH ROW EXECUTE FUNCTION public.check_file_size();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow authenticated users to upload their own avatar'
  ) THEN
    CREATE POLICY "Allow authenticated users to upload their own avatar"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'profiles' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow authenticated users to update their own avatar'
  ) THEN
    CREATE POLICY "Allow authenticated users to update their own avatar"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'profiles' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow authenticated users to delete their own avatar'
  ) THEN
    CREATE POLICY "Allow authenticated users to delete their own avatar"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'profiles' AND (storage.foldername(name))[1] = auth.uid()::text);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Allow public to view avatars'
  ) THEN
    CREATE POLICY "Allow public to view avatars"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'profiles');
  END IF;
END $$;

SET check_function_bodies = true;
