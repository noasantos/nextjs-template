-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T10:35:00Z

-- =====================================================
-- SINGLE SOURCE OF TRUTH: Controle de Acesso ao App
-- =====================================================
-- PROBLEMA: Lógica duplicada entre banco e código
-- SOLUÇÃO: Função única no banco que determina se usuário pode acessar o app
--
-- Esta função é a ÚNICA fonte de verdade para:
-- - AuthGuard (requireInitialOnboarding)
-- - Proxy/Middleware
-- - Qualquer verificação de acesso

-- =====================================================
-- 1. Função Única: Can User Access App?
-- =====================================================

CREATE OR REPLACE FUNCTION public.can_user_access_app(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role public.app_role;
  v_essential_complete BOOLEAN;
BEGIN
  -- Usuário não autenticado = não pode acessar
  IF p_user_id IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Buscar role do usuário
  SELECT role INTO v_role
  FROM public.user_roles
  WHERE user_id = p_user_id;
  
  -- Non-psychologists não têm onboarding, liberar acesso
  IF v_role IS NULL OR v_role != 'psychologist' THEN
    RETURN TRUE;
  END IF;
  
  -- Psicólogos: verificar Fase 1 (Essencial) na view consolidada
  SELECT essential_complete INTO v_essential_complete
  FROM public.psychologist_onboarding_summary
  WHERE psychologist_id = p_user_id;
  
  -- Retornar status (default FALSE se não encontrado)
  RETURN COALESCE(v_essential_complete, FALSE);
END;
$$;
COMMENT ON FUNCTION public.can_user_access_app(UUID) IS 
'SINGLE SOURCE OF TRUTH para controle de acesso ao app.
Retorna TRUE apenas quando Fase 1 (Essencial) está completa:
- identity_step_completed = TRUE
- professional_step_completed = TRUE  
- subscription_status IN (active, trialing) OR payment_step_completed = TRUE

Usar esta função em:
- AuthGuard (no lugar de get_onboarding_status_by_user)
- Proxy/Middleware
- Qualquer verificação de acesso ao app';
-- =====================================================
-- 2. Atualizar função legada para usar a nova
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_onboarding_status_by_user(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Delegar para a função única de controle de acesso
  RETURN public.can_user_access_app(p_user_id);
END;
$$;
COMMENT ON FUNCTION public.get_onboarding_status_by_user(UUID) IS 
'DEPRECATED: Use can_user_access_app() para nova implementação.
Mantida para compatibilidade com código existente.';
-- =====================================================
-- 3. Criar função para verificar subscription isoladamente
--    (para casos onde precisamos saber apenas do pagamento)
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_user_subscription_status(p_user_id UUID)
RETURNS TABLE(
  status TEXT,
  is_active BOOLEAN,
  has_essential_access BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(up.subscription_status, 'inactive')::TEXT as status,
    COALESCE(up.subscription_status IN ('active', 'trialing'), FALSE) as is_active,
    pos.essential_complete as has_essential_access
  FROM public.psychologist_onboarding_summary pos
  LEFT JOIN public.user_psychologists up ON up.id = pos.psychologist_id
  WHERE pos.psychologist_id = p_user_id;
END;
$$;
COMMENT ON FUNCTION public.get_user_subscription_status(UUID) IS 
'Retorna detalhes da subscription do usuário.
- status: status bruto da subscription
- is_active: TRUE se active/trialing
- has_essential_access: TRUE se pode acessar app (Fase 1 completa)

Usar para:
- Mostrar status de pagamento na UI
- Verificar se usuário precisa renovar
- NOTA: Para controle de acesso, usar can_user_access_app()';
-- =====================================================
-- 4. Garantir que índices existam para performance
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_psychologist_onboarding_state_psychologist_id 
  ON public.psychologist_onboarding_state(psychologist_id);
-- =====================================================
-- 5. Documentação das regras de acesso
-- =====================================================

COMMENT ON VIEW public.psychologist_onboarding_summary IS 
'SINGLE SOURCE OF TRUTH para progresso de onboarding.

REGRAS DE ACESSO (Fase 1 - Essencial):
- essential_complete = identity AND professional AND (subscription_active OR payment)
- Quando TRUE: usuário pode acessar o app
- Quando FALSE: usuário deve completar onboarding

COMPONENTES:
- identity_step_completed: nome, telefone, data nascimento
- professional_step_completed: CPF, CRP, documento
- payment/subscription: assinatura ativa ou pagamento confirmado

FUNÇÕES RELACIONADAS:
- can_user_access_app(): use para verificar permissão de acesso
- get_user_subscription_status(): use para mostrar status na UI';
SELECT 'Single source of truth criada com sucesso' as result;
