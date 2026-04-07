-- Fix get_subscription_status_by_user: table was renamed psychologists → user_psychologists
-- in migration 20260217132046 but this function was not updated at the time.

create or replace function public.get_subscription_status_by_user(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  p_role public.app_role;
  p_status text;
begin
  if p_user_id is null then
    return 'none';
  end if;

  select role into p_role
  from public.user_roles
  where user_id = p_user_id;

  if p_role is null or p_role != 'psychologist' then
    return 'none';
  end if;

  select subscription_status into p_status
  from public.user_psychologists
  where id = p_user_id;

  return coalesce(p_status, 'none');
end;
$$;
