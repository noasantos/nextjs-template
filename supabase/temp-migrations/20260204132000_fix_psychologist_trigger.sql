-- Fix: Recriar o trigger para criar registro na tabela psychologists quando um novo psicólogo é provisionado
-- O trigger havia sido perdido, causando erro 406 ao tentar buscar psicólogo inexistente

DROP TRIGGER IF EXISTS on_psychologist_created ON public.user_roles;
CREATE TRIGGER on_psychologist_created
    AFTER INSERT ON public.user_roles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_psychologist();
-- Adicionar comentário para documentação
COMMENT ON TRIGGER on_psychologist_created ON public.user_roles IS 
  'Cria automaticamente um registro na tabela psychologists quando um usuário recebe a role psychologist';
