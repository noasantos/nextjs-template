-- ============================================================================
-- Migration: Remove global practice_modality, derive from availability config
-- ============================================================================
-- practice_modality was a global setting on psychologist_profiles ("I'm hybrid").
-- The correct model: modality is configured per availability interval in
-- psychologist_availability.delivery_mode. The global value is derived.
-- ============================================================================

-- 1. Create a view that derives modality from availability intervals
CREATE OR REPLACE VIEW public.psychologist_derived_modality AS
SELECT
  pa.psychologist_id,
  CASE
    WHEN bool_or(pa.delivery_mode = 'hybrid') THEN 'hybrid'::public.practice_modality
    WHEN bool_or(pa.delivery_mode = 'in_person') AND bool_or(pa.delivery_mode = 'telehealth') THEN 'hybrid'::public.practice_modality
    WHEN bool_or(pa.delivery_mode = 'in_person') THEN 'in_person'::public.practice_modality
    WHEN bool_or(pa.delivery_mode = 'telehealth') THEN 'online'::public.practice_modality
    ELSE 'online'::public.practice_modality
  END AS practice_modality
FROM public.psychologist_availability pa
WHERE pa.is_active = true
  AND (pa.effective_start IS NULL OR pa.effective_start <= CURRENT_DATE)
  AND (pa.effective_end IS NULL OR pa.effective_end >= CURRENT_DATE)
GROUP BY pa.psychologist_id;
-- Grant access
GRANT SELECT ON public.psychologist_derived_modality TO authenticated, anon, service_role;
-- 2. Drop practice_modality from psychologist_profiles
ALTER TABLE public.psychologist_profiles
  DROP COLUMN IF EXISTS practice_modality;
-- 3. Drop practice_modality from marketplace_psychologist_profiles
ALTER TABLE public.marketplace_psychologist_profiles
  DROP COLUMN IF EXISTS practice_modality;
-- 4. Recreate sync_marketplace_profile WITHOUT practice_modality
CREATE OR REPLACE FUNCTION public.sync_marketplace_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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

  SELECT crp, crp_state
  INTO v_crp, v_crp_state
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
    NEW.slug,
    NEW.tagline,
    v_crp,
    v_crp_state,
    NEW.bio,
    NEW.specialties,
    NEW.therapeutic_approaches,
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
-- 5. Update check_profile_completion — replace practice_modality check
--    with a check on whether availability intervals are configured
CREATE OR REPLACE FUNCTION public.check_profile_completion(p_psychologist_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  completion_score integer := 0;
  max_score integer := 8;
BEGIN
  SELECT
    CASE WHEN display_name IS NOT NULL AND length(trim(display_name)) > 0 THEN 1 ELSE 0 END +
    CASE WHEN bio IS NOT NULL AND length(trim(bio)) > 50 THEN 1 ELSE 0 END +
    CASE WHEN avatar_url IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN array_length(specialties, 1) > 0 THEN 1 ELSE 0 END +
    CASE WHEN array_length(therapeutic_approaches, 1) > 0 THEN 1 ELSE 0 END +
    CASE WHEN EXISTS (
      SELECT 1 FROM public.psychologist_availability pa
      WHERE pa.psychologist_id = p_psychologist_id AND pa.is_active = true
    ) THEN 1 ELSE 0 END +
    CASE WHEN city IS NOT NULL AND state IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN languages IS NOT NULL AND array_length(languages, 1) > 0 THEN 1 ELSE 0 END
  INTO completion_score
  FROM public.psychologist_profiles
  WHERE id = p_psychologist_id;

  UPDATE public.psychologist_profiles
  SET profile_completed = (completion_score >= 6)
  WHERE id = p_psychologist_id;

  RETURN completion_score >= 6;
END;
$$;
