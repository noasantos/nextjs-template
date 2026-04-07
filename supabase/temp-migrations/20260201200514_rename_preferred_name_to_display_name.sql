-- Rename preferred_name to display_name across all tables
-- This migration handles both the psychologists table and the marketplace subset tables

BEGIN;
-- 1. Table: public.psychologists
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologists' AND column_name = 'preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologists' AND column_name = 'display_name') THEN
      ALTER TABLE public.psychologists RENAME COLUMN preferred_name TO display_name;
    ELSE
      ALTER TABLE public.psychologists DROP COLUMN preferred_name;
    END IF;
  END IF;
END $$;
-- 2. Table: public.marketplace_psychologist_profiles
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'marketplace_psychologist_profiles' AND column_name = 'preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'marketplace_psychologist_profiles' AND column_name = 'display_name') THEN
      ALTER TABLE public.marketplace_psychologist_profiles RENAME COLUMN preferred_name TO display_name;
    ELSE
      ALTER TABLE public.marketplace_psychologist_profiles DROP COLUMN preferred_name;
    END IF;
  END IF;
END $$;
-- 3. Table: public.psychologist_clients
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologist_clients' AND column_name = 'manual_preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologist_clients' AND column_name = 'manual_display_name') THEN
      ALTER TABLE public.psychologist_clients RENAME COLUMN manual_preferred_name TO manual_display_name;
    ELSE
      ALTER TABLE public.psychologist_clients DROP COLUMN manual_preferred_name;
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologist_clients' AND column_name = 'synced_preferred_name') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'psychologist_clients' AND column_name = 'synced_display_name') THEN
      ALTER TABLE public.psychologist_clients RENAME COLUMN synced_preferred_name TO synced_display_name;
    ELSE
      ALTER TABLE public.psychologist_clients DROP COLUMN synced_preferred_name;
    END IF;
  END IF;
END $$;
-- 4. Update sync_marketplace_profile function to use new column name
CREATE OR REPLACE FUNCTION public.sync_marketplace_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_username text;
  v_professional_title text;
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

  SELECT username, professional_title, crp, crp_state
  INTO v_username, v_professional_title, v_crp, v_crp_state
  FROM public.psychologists
  WHERE id = NEW.id;

  INSERT INTO public.marketplace_psychologist_profiles (
    psychologist_id,
    display_name,
    full_name,
    username,
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
    v_username,
    v_professional_title,
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
