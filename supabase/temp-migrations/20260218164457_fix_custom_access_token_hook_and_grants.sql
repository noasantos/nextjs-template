-- Fix custom_access_token_hook:
-- 1. Rename table reference from public.psychologists → public.user_psychologists
--    (table was renamed in the identity refactor and hook was never updated)
-- 2. Grant EXECUTE to supabase_auth_admin so Supabase Auth can actually invoke it
-- 3. Revoke EXECUTE from PUBLIC/authenticated/anon (security hardening)

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  sub_status text;
  p_user_id uuid;
BEGIN
  p_user_id := (event->>'user_id')::uuid;
  claims := coalesce(event->'claims', '{}'::jsonb);

  BEGIN
    SELECT role INTO user_role
    FROM public.user_roles
    WHERE user_id = p_user_id;

    IF user_role IS NOT NULL THEN
      claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
    ELSE
      claims := jsonb_set(claims, '{user_role}', 'null');
    END IF;

    IF user_role = 'psychologist' THEN
      SELECT onboarding_completed, subscription_status
      INTO onboarding_status, sub_status
      FROM public.user_psychologists
      WHERE id = p_user_id;

      claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
      claims := jsonb_set(claims, '{subscription_status}', to_jsonb(coalesce(sub_status, 'none')));
    ELSE
      claims := jsonb_set(claims, '{onboarding_completed}', 'true');
      claims := jsonb_set(claims, '{subscription_status}', '"none"');
    END IF;

  EXCEPTION WHEN OTHERS THEN
    claims := jsonb_set(claims, '{user_role}', 'null');
    claims := jsonb_set(claims, '{onboarding_completed}', 'false');
    claims := jsonb_set(claims, '{subscription_status}', '"none"');
  END;

  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$;
-- Allow Supabase Auth to invoke the hook
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin;
-- Revoke from public roles (hook is internal, not a client RPC)
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook FROM PUBLIC, authenticated, anon;
