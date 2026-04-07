-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-28T18:10:51Z
-- Migration: add_profiles_storage_bucket
-- Description: Adds the profiles bucket for storing user avatars during onboarding

-- Create the profiles bucket for avatar/profile image uploads
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profiles',
  'profiles',
  true,
  5242880, -- 5MB max file size
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET 
  name = EXCLUDED.name,
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = NOW();

-- Note: RLS is already enabled by default on storage.objects in Supabase
-- We only need to create the policies below

-- Allow authenticated users to upload their own files
CREATE POLICY "Allow authenticated users to upload their own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'profiles' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Allow authenticated users to update their own files
CREATE POLICY "Allow authenticated users to update their own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'profiles' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Allow authenticated users to delete their own files
CREATE POLICY "Allow authenticated users to delete their own avatar"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'profiles' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Allow public to view avatars
CREATE POLICY "Allow public to view avatars"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'profiles');
