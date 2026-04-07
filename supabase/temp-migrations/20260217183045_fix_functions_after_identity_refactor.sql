-- Migration: fix_functions_after_identity_refactor
-- Description: Update functions and triggers to use new user_ prefixed table names
-- AFTER: rename_core_identity_tables_to_user_prefix

-------------------------------------------------------------------------------
-- 1. UPDATE CORE FUNCTIONS
-------------------------------------------------------------------------------

-- Update ensure_psychologist_for_current_user function
CREATE OR REPLACE FUNCTION public.ensure_psychologist_for_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  insert into public.user_psychologists (id)
  values (v_user_id)
  on conflict (id) do nothing;
end;
$$;
COMMENT ON FUNCTION public.ensure_psychologist_for_current_user() IS 'Ensures a psychologist record exists for the current user (used by triggers)';
-------------------------------------------------------------------------------

-- Update handle_new_psychologist trigger function
CREATE OR REPLACE FUNCTION public.handle_new_psychologist()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.role = 'psychologist' THEN
    -- Insere apenas o ID, sem o email (que está em auth.users)
    INSERT INTO public.user_psychologists (id)
    VALUES (NEW.user_id)
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;
COMMENT ON FUNCTION public.handle_new_psychologist() IS 'Trigger function to create psychologist record on new user_roles insert';
-------------------------------------------------------------------------------

-- Update provision_user_role function
CREATE OR REPLACE FUNCTION public.provision_user_role(p_user_id uuid, p_role public.app_role)
RETURNS public.app_role
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_existing_role public.app_role;
begin
  select role into v_existing_role from public.user_roles where user_id = p_user_id;
  if v_existing_role is not null then
    return v_existing_role;
  end if;
  insert into public.user_roles (user_id, role) values (p_user_id, p_role);
  case p_role
    when 'psychologist' then
      insert into public.user_psychologists (id, subscription_status, onboarding_completed)
      values (p_user_id, 'inactive', false)
      on conflict (id) do nothing;
    when 'patient' then
      insert into public.user_patients (id) values (p_user_id) on conflict (id) do nothing;
    when 'assistant' then
      insert into public.user_assistants (id) values (p_user_id) on conflict (id) do nothing;
    when 'admin' then
      insert into public.user_admins (id) values (p_user_id) on conflict (id) do nothing;
  end case;
  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('user_role', p_role)
  where id = p_user_id;
  return p_role;
end;
$$;
COMMENT ON FUNCTION public.provision_user_role(uuid, public.app_role) IS 'Provisions a user role and creates the corresponding identity record';
-------------------------------------------------------------------------------

-- Update sync_marketplace_profile function
CREATE OR REPLACE FUNCTION public.sync_marketplace_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
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
  FROM public.user_psychologists
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
COMMENT ON FUNCTION public.sync_marketplace_profile() IS 'Syncs public profile data to marketplace tables when profile changes';
-------------------------------------------------------------------------------
-- 2. UPDATE OTHER AFFECTED FUNCTIONS
-------------------------------------------------------------------------------

-- Update complete_psychologist_onboarding if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p 
             JOIN pg_namespace n ON p.pronamespace = n.oid 
             WHERE n.nspname = 'public' AND p.proname = 'complete_psychologist_onboarding') THEN
    -- Function exists, check if it needs updating
    DECLARE
      v_func_source text;
    BEGIN
      SELECT p.prosrc INTO v_func_source
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE n.nspname = 'public' AND p.proname = 'complete_psychologist_onboarding';
      
      IF v_func_source ILIKE '%psychologists%' AND NOT v_func_source ILIKE '%user_psychologists%' THEN
        -- Function references old table name, needs recreation
        -- Note: This is a placeholder - the actual function definition would need to be retrieved and modified
        RAISE NOTICE 'Function complete_psychologist_onboarding references old table name and may need manual update';
      END IF;
    END;
  END IF;
END $$;
-- Update get_onboarding_status if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p 
             JOIN pg_namespace n ON p.pronamespace = n.oid 
             WHERE n.nspname = 'public' AND p.proname = 'get_onboarding_status') THEN
    RAISE NOTICE 'Function get_onboarding_status may need review for psychologists table references';
  END IF;
END $$;
-- Update get_onboarding_status_by_user if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p 
             JOIN pg_namespace n ON p.pronamespace = n.oid 
             WHERE n.nspname = 'public' AND p.proname = 'get_onboarding_status_by_user') THEN
    RAISE NOTICE 'Function get_onboarding_status_by_user may need review for psychologists table references';
  END IF;
END $$;
-- Update get_subscription_status_by_user if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p 
             JOIN pg_namespace n ON p.pronamespace = n.oid 
             WHERE n.nspname = 'public' AND p.proname = 'get_subscription_status_by_user') THEN
    RAISE NOTICE 'Function get_subscription_status_by_user may need review for psychologists table references';
  END IF;
END $$;
-- Update complete_psychologist_onboarding function
CREATE OR REPLACE FUNCTION public.complete_psychologist_onboarding()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  p_user_id uuid;
  p_role public.app_role;
begin
  
  p_user_id := auth.uid();
  
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  if p_role != 'psychologist' then
    raise exception 'Only psychologists can complete onboarding';
  end if;
  
  
  update public.user_psychologists
  set 
    onboarding_completed = true,
    updated_at = now()
  where id = p_user_id;
  
  
  return true;
end;
$$;
COMMENT ON FUNCTION public.complete_psychologist_onboarding() IS 'Marks psychologist onboarding as completed';
-- Update get_public_psychologist_by_username if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p 
             JOIN pg_namespace n ON p.pronamespace = n.oid 
             WHERE n.nspname = 'public' AND p.proname = 'get_public_psychologist_by_username') THEN
    RAISE NOTICE 'Function get_public_psychologist_by_username may need review for psychologists table references';
  END IF;
END $$;
-- Update custom_access_token_hook if it exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p 
             JOIN pg_namespace n ON p.pronamespace = n.oid 
             WHERE n.nspname = 'public' AND p.proname = 'custom_access_token_hook') THEN
    RAISE NOTICE 'Function custom_access_token_hook may need review for psychologists table references';
  END IF;
END $$;
-------------------------------------------------------------------------------
-- 4. UPDATE RPC FUNCTIONS (Return Types/Queries)
-------------------------------------------------------------------------------

-- Update get_public_psychologist_by_username
CREATE OR REPLACE FUNCTION public.get_public_psychologist_by_username(p_username text)
RETURNS TABLE (
    id uuid,
    full_name text,
    avatar_url text,
    crp text,
    crp_state text,
    bio text,
    specialties jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.crp,
    p.crp_state,
    pp.bio, 
    pp.specialties::jsonb
  FROM user_psychologists p
  LEFT JOIN psychologist_profiles pp ON p.id = pp.id
  WHERE p.username = p_username;
END;
$$;
COMMENT ON FUNCTION public.get_public_psychologist_by_username(text) IS 'Retrieves public psychologist profile by username';
-------------------------------------------------------------------------------
-- 3. TABLE DESCRIPTIONS
-------------------------------------------------------------------------------

COMMENT ON TABLE public.user_admins IS 'Core identity table for internal platform administrators. Extends auth.users.';
COMMENT ON TABLE public.user_assistants IS 'Core identity table for clinic assistants and secretaries. Extends auth.users.';
COMMENT ON TABLE public.user_patients IS 'Core identity table for patients (global profile). Extends auth.users.';
COMMENT ON TABLE public.user_psychologists IS 'Core identity table for psychologists (the primary platform users). Extends auth.users.';
