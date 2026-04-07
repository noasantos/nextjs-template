-- Migration: RPC para garantir que o psicólogo logado tenha registro em psychologists
-- Usado quando o trigger on_psychologist_created não disparou (ex: usuários antigos)
-- Apenas insere para auth.uid() atual; não permite criar registro para outro usuário

create or replace function public.ensure_psychologist_for_current_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  insert into public.psychologists (id)
  values (v_user_id)
  on conflict (id) do nothing;
end;
$$;
comment on function public.ensure_psychologist_for_current_user() is
  'Cria registro em psychologists para o usuário autenticado se não existir. Usado como fallback quando o trigger on_psychologist_created não disparou.';
