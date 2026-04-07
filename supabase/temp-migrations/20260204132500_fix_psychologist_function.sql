-- Fix: Atualizar a função handle_new_psychologist para não inserir a coluna email
-- A coluna email foi removida da tabela psychologists pois o email já existe em auth.users

CREATE OR REPLACE FUNCTION public.handle_new_psychologist()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'psychologist' THEN
    -- Insere apenas o ID, sem o email (que está em auth.users)
    INSERT INTO public.psychologists (id)
    VALUES (NEW.user_id)
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;
-- Recriar o trigger para garantir que use a função atualizada
DROP TRIGGER IF EXISTS on_psychologist_created ON public.user_roles;
CREATE TRIGGER on_psychologist_created
    AFTER INSERT ON public.user_roles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_psychologist();
