-- Public marketplace safe tables and policies

-- Helper: public profile status (security definer to avoid exposing base table)
CREATE OR REPLACE FUNCTION public.is_profile_public(p_psychologist_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.psychologist_profiles pp
    WHERE pp.id = p_psychologist_id
      AND pp.is_public = true
      AND COALESCE(pp.show_in_marketplace, true) = true
      AND pp.display_name IS NOT NULL
  );
$$;
-- Marketplace profiles (safe subset)
CREATE TABLE IF NOT EXISTS public.marketplace_psychologist_profiles (
  psychologist_id uuid PRIMARY KEY REFERENCES public.psychologist_profiles(id) ON DELETE CASCADE,
  display_name text,
  full_name text,
  username text,
  professional_title text,
  crp text,
  crp_state text,
  bio text,
  specialties text[],
  therapeutic_approaches text[],
  practice_modality public.practice_modality,
  session_duration integer,
  session_price numeric,
  city text,
  state text,
  languages text[],
  avatar_url text,
  avatar_path text,
  background_url text,
  background_path text,
  slug text,
  social_links jsonb,
  linktree_theme text,
  tagline text,
  profile_sections jsonb,
  video_section jsonb,
  academic_timeline jsonb,
  gallery_photos text[],
  is_public boolean,
  show_in_marketplace boolean,
  created_at timestamptz,
  updated_at timestamptz
);
-- Marketplace linktree links
CREATE TABLE IF NOT EXISTS public.marketplace_linktree_links (
  id uuid PRIMARY KEY,
  psychologist_id uuid NOT NULL REFERENCES public.psychologist_profiles(id) ON DELETE CASCADE,
  title text,
  url text,
  is_active boolean,
  sort_order integer,
  created_at timestamptz,
  updated_at timestamptz
);
-- Marketplace locations (safe subset)
CREATE TABLE IF NOT EXISTS public.marketplace_locations (
  id uuid PRIMARY KEY,
  psychologist_id uuid NOT NULL REFERENCES public.psychologist_profiles(id) ON DELETE CASCADE,
  name text,
  city text,
  state text,
  country text,
  latitude numeric,
  longitude numeric,
  is_primary boolean,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
);
-- Backfill marketplace tables for existing public profiles
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
)
SELECT
  pp.id,
  pp.display_name,
  pp.full_name,
  p.username,
  p.professional_title,
  p.crp,
  p.crp_state,
  pp.bio,
  pp.specialties,
  pp.therapeutic_approaches,
  pp.practice_modality,
  pp.session_duration,
  pp.session_price,
  pp.city,
  pp.state,
  pp.languages,
  pp.avatar_url,
  pp.avatar_path,
  pp.background_url,
  pp.background_path,
  pp.slug,
  pp.social_links,
  pp.linktree_theme,
  pp.tagline,
  pp.profile_sections,
  pp.video_section,
  pp.academic_timeline,
  pp.gallery_photos,
  pp.is_public,
  pp.show_in_marketplace,
  pp.created_at,
  pp.updated_at
FROM public.psychologist_profiles pp
JOIN public.psychologists p ON p.id = pp.id
WHERE public.is_profile_public(pp.id)
ON CONFLICT (psychologist_id) DO NOTHING;
INSERT INTO public.marketplace_linktree_links (
  id,
  psychologist_id,
  title,
  url,
  is_active,
  sort_order,
  created_at,
  updated_at
)
SELECT
  l.id,
  l.psychologist_id,
  l.title,
  l.url,
  l.is_active,
  l.sort_order,
  l.created_at,
  l.updated_at
FROM public.linktree_links l
WHERE public.is_profile_public(l.psychologist_id)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.marketplace_locations (
  id,
  psychologist_id,
  name,
  city,
  state,
  country,
  latitude,
  longitude,
  is_primary,
  is_active,
  created_at,
  updated_at
)
SELECT
  loc.id,
  loc.psychologist_id,
  loc.name,
  loc.city,
  loc.state,
  loc.country,
  loc.latitude,
  loc.longitude,
  loc.is_primary,
  loc.is_active,
  loc.created_at,
  loc.updated_at
FROM public.psychologist_locations loc
WHERE public.is_profile_public(loc.psychologist_id)
ON CONFLICT (id) DO NOTHING;
-- Sync marketplace profiles from psychologist_profiles (and psychologists)
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
CREATE OR REPLACE FUNCTION public.sync_marketplace_linktree_link()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM public.marketplace_linktree_links WHERE id = OLD.id;
    RETURN OLD;
  END IF;

  IF NOT public.is_profile_public(NEW.psychologist_id) THEN
    DELETE FROM public.marketplace_linktree_links WHERE id = NEW.id;
    RETURN NEW;
  END IF;

  INSERT INTO public.marketplace_linktree_links (
    id,
    psychologist_id,
    title,
    url,
    is_active,
    sort_order,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    NEW.psychologist_id,
    NEW.title,
    NEW.url,
    NEW.is_active,
    NEW.sort_order,
    NEW.created_at,
    NEW.updated_at
  ) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    url = EXCLUDED.url,
    is_active = EXCLUDED.is_active,
    sort_order = EXCLUDED.sort_order,
    updated_at = EXCLUDED.updated_at;

  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION public.sync_marketplace_location()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    DELETE FROM public.marketplace_locations WHERE id = OLD.id;
    RETURN OLD;
  END IF;

  IF NOT public.is_profile_public(NEW.psychologist_id) THEN
    DELETE FROM public.marketplace_locations WHERE id = NEW.id;
    RETURN NEW;
  END IF;

  INSERT INTO public.marketplace_locations (
    id,
    psychologist_id,
    name,
    city,
    state,
    country,
    latitude,
    longitude,
    is_primary,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    NEW.psychologist_id,
    NEW.name,
    NEW.city,
    NEW.state,
    NEW.country,
    NEW.latitude,
    NEW.longitude,
    NEW.is_primary,
    NEW.is_active,
    NEW.created_at,
    NEW.updated_at
  ) ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    city = EXCLUDED.city,
    state = EXCLUDED.state,
    country = EXCLUDED.country,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    is_primary = EXCLUDED.is_primary,
    is_active = EXCLUDED.is_active,
    updated_at = EXCLUDED.updated_at;

  RETURN NEW;
END;
$$;
-- Triggers
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'sync_marketplace_profile') THEN
    CREATE TRIGGER sync_marketplace_profile
    AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_profiles
    FOR EACH ROW EXECUTE FUNCTION public.sync_marketplace_profile();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'sync_marketplace_linktree_links') THEN
    CREATE TRIGGER sync_marketplace_linktree_links
    AFTER INSERT OR UPDATE OR DELETE ON public.linktree_links
    FOR EACH ROW EXECUTE FUNCTION public.sync_marketplace_linktree_link();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'sync_marketplace_locations') THEN
    CREATE TRIGGER sync_marketplace_locations
    AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_locations
    FOR EACH ROW EXECUTE FUNCTION public.sync_marketplace_location();
  END IF;
END $$;
-- RLS on marketplace tables (public read)
ALTER TABLE public.marketplace_psychologist_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_linktree_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS marketplace_profiles_select_anon ON public.marketplace_psychologist_profiles;
CREATE POLICY marketplace_profiles_select_anon
ON public.marketplace_psychologist_profiles
FOR SELECT
TO anon
USING (true);
DROP POLICY IF EXISTS marketplace_profiles_select_auth ON public.marketplace_psychologist_profiles;
CREATE POLICY marketplace_profiles_select_auth
ON public.marketplace_psychologist_profiles
FOR SELECT
TO authenticated
USING (true);
DROP POLICY IF EXISTS marketplace_linktree_select_anon ON public.marketplace_linktree_links;
CREATE POLICY marketplace_linktree_select_anon
ON public.marketplace_linktree_links
FOR SELECT
TO anon
USING (true);
DROP POLICY IF EXISTS marketplace_linktree_select_auth ON public.marketplace_linktree_links;
CREATE POLICY marketplace_linktree_select_auth
ON public.marketplace_linktree_links
FOR SELECT
TO authenticated
USING (true);
DROP POLICY IF EXISTS marketplace_locations_select_anon ON public.marketplace_locations;
CREATE POLICY marketplace_locations_select_anon
ON public.marketplace_locations
FOR SELECT
TO anon
USING (true);
DROP POLICY IF EXISTS marketplace_locations_select_auth ON public.marketplace_locations;
CREATE POLICY marketplace_locations_select_auth
ON public.marketplace_locations
FOR SELECT
TO authenticated
USING (true);
-- Update psychologist_services public policy to use safe function
DROP POLICY IF EXISTS psychologist_services_select_anon ON public.psychologist_services;
CREATE POLICY psychologist_services_select_anon
ON public.psychologist_services
FOR SELECT
TO anon
USING (is_active = true AND public.is_profile_public(psychologist_id));
DROP POLICY IF EXISTS psychologist_services_select_authenticated ON public.psychologist_services;
CREATE POLICY psychologist_services_select_authenticated
ON public.psychologist_services
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = psychologist_id OR (is_active = true AND public.is_profile_public(psychologist_id)));
