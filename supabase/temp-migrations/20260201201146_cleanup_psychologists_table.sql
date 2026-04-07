-- Cleanup psychologists table and consolidate website/profile settings
-- This migration removes redundant columns and moves website-related data to psychologist_profiles

BEGIN;
-- 1. Ensure all data is synced to psychologist_profiles before dropping from psychologists
-- We use a subquery to avoid issues if columns are already missing in some environments
DO $$ 
BEGIN
    -- Sync bio, professional_title, display_name, slug/username if they exist in psychologists
    UPDATE public.psychologist_profiles pp
    SET 
        bio = COALESCE(pp.bio, p.bio),
        tagline = COALESCE(pp.tagline, p.professional_title),
        display_name = COALESCE(pp.display_name, p.display_name),
        slug = COALESCE(pp.slug, p.slug, p.username),
        avatar_url = COALESCE(pp.avatar_url, p.avatar_url),
        avatar_path = COALESCE(pp.avatar_path, p.avatar_path),
        practice_modality = COALESCE(pp.practice_modality, p.practice_modality)
    FROM public.psychologists p
    WHERE pp.id = p.id;
EXCEPTION WHEN OTHERS THEN
    -- If some columns are already gone, we ignore and proceed with the drop
    NULL;
END $$;
-- 2. Cleanup redundant triggers and functions BEFORE dropping columns
-- This avoids dependency errors (SQLSTATE 2BP01)
DROP TRIGGER IF EXISTS sync_practice_modality_trigger ON public.psychologists;
DROP FUNCTION IF EXISTS public.sync_practice_modality_to_profile();
-- 3. Remove columns from public.psychologists
-- Note: we use CASCADE to drop dependent objects like views (psychologist_subscriptions)
ALTER TABLE public.psychologists 
    DROP COLUMN IF EXISTS email CASCADE, -- Redundant with auth.users
    DROP COLUMN IF EXISTS professional_title CASCADE, -- Moved to profiles.tagline
    DROP COLUMN IF EXISTS bio CASCADE, -- Moved to profiles
    DROP COLUMN IF EXISTS avatar_url CASCADE, -- Moved to profiles
    DROP COLUMN IF EXISTS avatar_path CASCADE, -- Moved to profiles
    DROP COLUMN IF EXISTS background_url CASCADE, -- Moved to profiles
    DROP COLUMN IF EXISTS background_path CASCADE, -- Moved to profiles
    DROP COLUMN IF EXISTS username CASCADE, -- Redundant with slug
    DROP COLUMN IF EXISTS slug CASCADE, -- Moved to profiles
    DROP COLUMN IF EXISTS practice_modality CASCADE, -- Moved to profiles
    DROP COLUMN IF EXISTS patient_volume CASCADE, -- Requested removal
    DROP COLUMN IF EXISTS feature_priorities CASCADE;
-- Requested removal (if exists)

-- 4. Ensure psychologist_profiles has the necessary columns for the website
-- (Most already exist, but we ensure slug is there and unique)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologist_profiles' AND column_name = 'slug') THEN
        ALTER TABLE public.psychologist_profiles ADD COLUMN slug text;
    END IF;
END $$;
-- Add unique constraint to slug in profiles if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'psychologist_profiles_slug_key') THEN
        ALTER TABLE public.psychologist_profiles ADD CONSTRAINT psychologist_profiles_slug_key UNIQUE (slug);
    END IF;
END $$;
-- 5. Update the sync trigger function to account for moved columns
CREATE OR REPLACE FUNCTION public.sync_marketplace_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_crp text;
  v_crp_state text;
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM public.marketplace_psychologist_profiles WHERE psychologist_id = OLD.id;
    DELETE FROM public.marketplace_linktree_links WHERE psychologist_id = OLD.id;
    DELETE FROM public.marketplace_locations WHERE psychologist_id = OLD.id;
    RETURN OLD;
  END IF;

  IF NOT public.is_profile_public(NEW.id) THEN
    DELETE FROM public.marketplace_psychologist_profiles WHERE psychologist_id = NEW.id;
    DELETE FROM public.marketplace_linktree_links WHERE psychologist_id = NEW.id;
    DELETE FROM public.marketplace_locations WHERE psychologist_id = NEW.id;
    RETURN NEW;
  END IF;

  -- Get remaining data from psychologists table
  SELECT crp, crp_state
  INTO v_crp, v_crp_state
  FROM public.psychologists
  WHERE id = NEW.id;

  INSERT INTO public.marketplace_psychologist_profiles (
    psychologist_id,
    display_name,
    full_name,
    username, -- We keep this in marketplace for compatibility or use slug
    professional_title,
    crp,
    crp_state,
    bio,
    specialties,
    therapeutic_approaches,
    practice_modality,
    session_duration,
    session_price,
    city,
    state,
    languages,
    avatar_url,
    avatar_path,
    background_url,
    background_path,
    slug,
    social_links,
    linktree_theme,
    tagline,
    profile_sections,
    video_section,
    academic_timeline,
    gallery_photos,
    is_public,
    show_in_marketplace,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    NEW.display_name,
    NEW.full_name,
    NEW.slug, -- Use slug as username in marketplace
    NEW.tagline, -- Use tagline as professional_title
    v_crp,
    v_crp_state,
    NEW.bio,
    NEW.specialties,
    NEW.therapeutic_approaches,
    NEW.practice_modality,
    NEW.session_duration,
    NEW.session_price,
    NEW.city,
    NEW.state,
    NEW.languages,
    NEW.avatar_url,
    NEW.avatar_path,
    NEW.background_url,
    NEW.background_path,
    NEW.slug,
    NEW.social_links,
    NEW.linktree_theme,
    NEW.tagline,
    NEW.profile_sections,
    NEW.video_section,
    NEW.academic_timeline,
    NEW.gallery_photos,
    NEW.is_public,
    NEW.show_in_marketplace,
    NEW.created_at,
    NEW.updated_at
  ) ON CONFLICT (psychologist_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    full_name = EXCLUDED.full_name,
    username = EXCLUDED.username,
    professional_title = EXCLUDED.professional_title,
    crp = EXCLUDED.crp,
    crp_state = EXCLUDED.crp_state,
    bio = EXCLUDED.bio,
    specialties = EXCLUDED.specialties,
    therapeutic_approaches = EXCLUDED.therapeutic_approaches,
    practice_modality = EXCLUDED.practice_modality,
    session_duration = EXCLUDED.session_duration,
    session_price = EXCLUDED.session_price,
    city = EXCLUDED.city,
    state = EXCLUDED.state,
    languages = EXCLUDED.languages,
    avatar_url = EXCLUDED.avatar_url,
    avatar_path = EXCLUDED.avatar_path,
    background_url = EXCLUDED.background_url,
    background_path = EXCLUDED.background_path,
    slug = EXCLUDED.slug,
    social_links = EXCLUDED.social_links,
    linktree_theme = EXCLUDED.linktree_theme,
    tagline = EXCLUDED.tagline,
    profile_sections = EXCLUDED.profile_sections,
    video_section = EXCLUDED.video_section,
    academic_timeline = EXCLUDED.academic_timeline,
    gallery_photos = EXCLUDED.gallery_photos,
    is_public = EXCLUDED.is_public,
    show_in_marketplace = EXCLUDED.show_in_marketplace,
    updated_at = EXCLUDED.updated_at;

  RETURN NEW;
END;
$$;
COMMIT;
