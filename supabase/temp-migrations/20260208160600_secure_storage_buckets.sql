-- 1. Create patient-documents bucket if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('patient-documents', 'patient-documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;
-- 2. Disable public access (redundant but safe)
UPDATE storage.buckets SET public = false WHERE id = 'patient-documents';
-- 3. RLS policy: Users can only read their own documents
-- The folder structure is {user_id}/{patient_id}/{filename}
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can read own documents" ON storage.objects;
    CREATE POLICY "Users can read own documents" ON storage.objects
      FOR SELECT TO authenticated
      USING (
        bucket_id = 'patient-documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
      );
END $$;
-- 4. RLS policy: Users can only upload to their own folder
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can upload to own folder" ON storage.objects;
    CREATE POLICY "Users can upload to own folder" ON storage.objects
      FOR INSERT TO authenticated
      WITH CHECK (
        bucket_id = 'patient-documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
      );
END $$;
-- 5. RLS policy: Users can only delete their own documents
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can delete own documents" ON storage.objects;
    CREATE POLICY "Users can delete own documents" ON storage.objects
      FOR DELETE TO authenticated
      USING (
        bucket_id = 'patient-documents' AND
        (storage.foldername(name))[1] = auth.uid()::text
      );
END $$;
-- 6. Add file size limit (10MB) via trigger
-- Keep function in public schema to avoid CREATE privilege requirements on storage schema.
CREATE OR REPLACE FUNCTION public.check_file_size()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.bucket_id = 'patient-documents'
     AND COALESCE((NEW.metadata->>'size')::bigint, 0) > 10485760 THEN
    RAISE EXCEPTION 'File too large. Maximum size is 10MB';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS check_file_size_trigger ON storage.objects;
CREATE TRIGGER check_file_size_trigger
  BEFORE INSERT ON storage.objects
  FOR EACH ROW EXECUTE FUNCTION public.check_file_size();
