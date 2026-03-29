-- Idempotent bootstrap for local `supabase db reset`.
--
-- Template roles: `user_roles.role` references `app_roles(role)`; seed before assigning roles in tests.
-- JWT enrichment: `custom_access_token_hook` reads roles from `user_roles` and `subscription` / `access_version`
-- from `profiles`; permissions in app_metadata stay an empty array until the product adds an app-layer model.

INSERT INTO public.app_roles (role, label, is_self_sign_up_allowed)
VALUES
  ('user', 'User', true),
  ('admin', 'Admin', false)
ON CONFLICT (role) DO UPDATE
SET label = EXCLUDED.label,
    is_self_sign_up_allowed = EXCLUDED.is_self_sign_up_allowed;
