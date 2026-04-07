-- migration-created-via: pnpm supabase:migration:new
-- Migration: refactor_onboarding_journey
-- Description: Consolida o controle de onboarding em uma única fonte de verdade
-- com estados claros separando "pagamento" (essencial) de "perfil completo" (wizard)

-- =====================================================
-- 1. ATUALIZAR TABELA EXISTENTE (adicionar colunas novas)
-- =====================================================

-- Adicionar colunas de controle granular à psychologist_onboarding_state
ALTER TABLE public.psychologist_onboarding_state
  ADD COLUMN IF NOT EXISTS payment_step_completed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS identity_step_completed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS professional_step_completed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS readiness_step_completed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS profile_step_completed BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS total_steps INTEGER DEFAULT 5,
  ADD COLUMN IF NOT EXISTS last_resumed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS abandoned_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS completion_percentage INTEGER DEFAULT 0;
-- Garantir que onboarding_completed_at existe
ALTER TABLE public.psychologist_onboarding_state
  ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMPTZ;
-- Comentários explicativos
COMMENT ON TABLE public.psychologist_onboarding_state IS 
'Estado de progresso do onboarding do psicólogo. Fonte única de verdade para jornada de onboarding.
- payment_step: essencial/bloqueante (usuário pagou = pode usar o sistema)
- identity/professional/readiness/profile: passos do wizard de perfil
- onboarding_completed_at: preenchido quando TODOS os passos são concluídos';
COMMENT ON COLUMN public.psychologist_onboarding_state.payment_step_completed IS 
'ESSENCIAL: Usuário pagou o plano. Quando TRUE, permite acesso ao sistema mesmo que outros passos estejam pendentes.';
COMMENT ON COLUMN public.psychologist_onboarding_state.identity_step_completed IS 
'Passo 1: Dados de identidade (nome, CRP, etc)';
COMMENT ON COLUMN public.psychologist_onboarding_state.professional_step_completed IS 
'Passo 2: Dados profissionais (especialidades, abordagens)';
COMMENT ON COLUMN public.psychologist_onboarding_state.readiness_step_completed IS 
'Passo 3: Configurações de prontidão (disponibilidade)';
COMMENT ON COLUMN public.psychologist_onboarding_state.profile_step_completed IS 
'Passo 4: Perfil público (bio, foto, etc)';
COMMENT ON COLUMN public.psychologist_onboarding_state.onboarding_completed_at IS 
'Data de conclusão completa do onboarding (todos os passos). NULL = onboarding incompleto.';
-- =====================================================
-- 2. FUNÇÃO: Atualizar percentual de conclusão
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_onboarding_progress(p_psychologist_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_completed_steps INTEGER := 0;
  v_total_steps INTEGER := 5;
  v_progress INTEGER;
  v_state RECORD;
BEGIN
  SELECT * INTO v_state 
  FROM public.psychologist_onboarding_state 
  WHERE psychologist_id = p_psychologist_id;
  
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  
  IF v_state.payment_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.identity_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.professional_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.readiness_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.profile_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  
  v_progress := (v_completed_steps * 100) / v_total_steps;
  
  -- Atualizar na tabela
  UPDATE public.psychologist_onboarding_state
  SET completion_percentage = v_progress,
      current_step = CASE 
        WHEN v_state.onboarding_completed_at IS NOT NULL THEN v_total_steps + 1
        WHEN v_state.profile_step_completed THEN 5
        WHEN v_state.readiness_step_completed THEN 4
        WHEN v_state.professional_step_completed THEN 3
        WHEN v_state.identity_step_completed THEN 2
        WHEN v_state.payment_step_completed THEN 1
        ELSE 1
      END
  WHERE psychologist_id = p_psychologist_id;
  
  RETURN v_progress;
END;
$$;
COMMENT ON FUNCTION public.calculate_onboarding_progress(UUID) IS 
'Calcula e atualiza o percentual de conclusão do onboarding baseado nos passos completados.';
-- =====================================================
-- 3. FUNÇÃO: Verificar se onboarding essencial está completo
-- =====================================================

CREATE OR REPLACE FUNCTION public.is_onboarding_essential_complete(p_psychologist_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_has_subscription BOOLEAN;
  v_has_payment_step BOOLEAN;
BEGIN
  -- Verificar se tem subscription ativa na tabela user_psychologists
  SELECT subscription_status IN ('active', 'trialing')
  INTO v_has_subscription
  FROM public.user_psychologists
  WHERE id = p_psychologist_id;
  
  -- Verificar se passo de pagamento está marcado
  SELECT payment_step_completed
  INTO v_has_payment_step
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = p_psychologist_id;
  
  -- Retorna TRUE se pagou OU se marcou o passo de pagamento
  RETURN COALESCE(v_has_subscription, FALSE) OR COALESCE(v_has_payment_step, FALSE);
END;
$$;
COMMENT ON FUNCTION public.is_onboarding_essential_complete(UUID) IS 
'Retorna TRUE se o onboarding ESSENCIAL está completo (usuário pagou = pode usar o sistema).';
-- =====================================================
-- 4. FUNÇÃO: Verificar se onboarding completo está finalizado
-- =====================================================

CREATE OR REPLACE FUNCTION public.is_onboarding_fully_complete(p_psychologist_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_state RECORD;
BEGIN
  SELECT * INTO v_state
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = p_psychologist_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Todos os passos devem estar completos
  RETURN v_state.onboarding_completed_at IS NOT NULL
    OR (
      v_state.payment_step_completed 
      AND v_state.identity_step_completed 
      AND v_state.professional_step_completed 
      AND v_state.readiness_step_completed 
      AND v_state.profile_step_completed
    );
END;
$$;
COMMENT ON FUNCTION public.is_onboarding_fully_complete(UUID) IS 
'Retorna TRUE se o onboarding COMPLETO (todos os passos) está finalizado.';
-- =====================================================
-- 5. VIEW: Resumo do onboarding para queries rápidas
-- =====================================================

CREATE OR REPLACE VIEW public.psychologist_onboarding_summary AS
SELECT 
  pos.psychologist_id,
  pos.payment_step_completed,
  pos.identity_step_completed,
  pos.professional_step_completed,
  pos.readiness_step_completed,
  pos.profile_step_completed,
  pos.current_step,
  pos.total_steps,
  pos.completion_percentage,
  pos.onboarding_completed_at,
  pos.last_resumed_at,
  pos.abandoned_at,
  -- Flags calculadas
  COALESCE(up.subscription_status IN ('active', 'trialing'), FALSE) 
    OR pos.payment_step_completed AS essential_complete,
  pos.onboarding_completed_at IS NOT NULL 
    OR (
      pos.payment_step_completed 
      AND pos.identity_step_completed 
      AND pos.professional_step_completed 
      AND pos.readiness_step_completed 
      AND pos.profile_step_completed
    ) AS fully_complete,
  -- Próximo passo pendente (para redirecionamento)
  CASE 
    WHEN pos.onboarding_completed_at IS NOT NULL THEN NULL
    WHEN NOT pos.payment_step_completed THEN 'subscription'
    WHEN NOT pos.identity_step_completed THEN 'identity'
    WHEN NOT pos.professional_step_completed THEN 'professional'
    WHEN NOT pos.readiness_step_completed THEN 'readiness'
    WHEN NOT pos.profile_step_completed THEN 'profile'
    ELSE NULL
  END AS next_pending_step,
  up.subscription_status
FROM public.psychologist_onboarding_state pos
LEFT JOIN public.user_psychologists up ON up.id = pos.psychologist_id;
COMMENT ON VIEW public.psychologist_onboarding_summary IS 
'View consolidada com resumo do estado de onboarding do psicólogo. Usar para verificar status e próximo passo.';
-- =====================================================
-- 6. RPC: Get onboarding status (substitui funções antigas)
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_onboarding_status_v2(p_user_id UUID DEFAULT NULL)
RETURNS TABLE (
  essential_complete BOOLEAN,
  fully_complete BOOLEAN,
  completion_percentage INTEGER,
  current_step INTEGER,
  total_steps INTEGER,
  next_pending_step TEXT,
  payment_completed BOOLEAN,
  identity_completed BOOLEAN,
  professional_completed BOOLEAN,
  readiness_completed BOOLEAN,
  profile_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Usar user_id passado ou o current_user
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 
      FALSE, FALSE, 0, 1, 5, 
      'subscription'::TEXT, 
      FALSE, FALSE, FALSE, FALSE, FALSE;
    RETURN;
  END IF;
  
  -- Garantir que registro existe
  INSERT INTO public.psychologist_onboarding_state (psychologist_id)
  VALUES (v_user_id)
  ON CONFLICT (psychologist_id) DO NOTHING;
  
  -- Atualizar progresso antes de retornar
  PERFORM public.calculate_onboarding_progress(v_user_id);
  
  RETURN QUERY
  SELECT 
    pos.essential_complete,
    pos.fully_complete,
    pos.completion_percentage,
    pos.current_step,
    pos.total_steps,
    pos.next_pending_step,
    pos.payment_step_completed,
    pos.identity_step_completed,
    pos.professional_step_completed,
    pos.readiness_step_completed,
    pos.profile_step_completed
  FROM public.psychologist_onboarding_summary pos
  WHERE pos.psychologist_id = v_user_id;
END;
$$;
COMMENT ON FUNCTION public.get_onboarding_status_v2(UUID) IS 
'Retorna o status completo do onboarding do usuário. Use esta função no lugar de get_onboarding_status() antiga.';
-- =====================================================
-- 7. RPC: Completar um passo específico do onboarding
-- =====================================================

CREATE OR REPLACE FUNCTION public.complete_onboarding_step(
  p_psychologist_id UUID,
  p_step TEXT  -- 'payment', 'identity', 'professional', 'readiness', 'profile'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_all_complete BOOLEAN;
BEGIN
  -- Atualizar o passo específico
  UPDATE public.psychologist_onboarding_state
  SET 
    payment_step_completed = CASE WHEN p_step = 'payment' THEN TRUE ELSE payment_step_completed END,
    identity_step_completed = CASE WHEN p_step = 'identity' THEN TRUE ELSE identity_step_completed END,
    professional_step_completed = CASE WHEN p_step = 'professional' THEN TRUE ELSE professional_step_completed END,
    readiness_step_completed = CASE WHEN p_step = 'readiness' THEN TRUE ELSE readiness_step_completed END,
    profile_step_completed = CASE WHEN p_step = 'profile' THEN TRUE ELSE profile_step_completed END,
    updated_at = NOW()
  WHERE psychologist_id = p_psychologist_id;
  
  -- Recalcular progresso
  PERFORM public.calculate_onboarding_progress(p_psychologist_id);
  
  -- Verificar se completou tudo
  SELECT (
    payment_step_completed 
    AND identity_step_completed 
    AND professional_step_completed 
    AND readiness_step_completed 
    AND profile_step_completed
  ) INTO v_all_complete
  FROM public.psychologist_onboarding_state
  WHERE psychologist_id = p_psychologist_id;
  
  -- Se completou tudo, marcar timestamp
  IF v_all_complete THEN
    UPDATE public.psychologist_onboarding_state
    SET onboarding_completed_at = COALESCE(onboarding_completed_at, NOW()),
        updated_at = NOW()
    WHERE psychologist_id = p_psychologist_id;
    
    -- Também atualizar a flag na user_psychologists para compatibilidade
    UPDATE public.user_psychologists
    SET onboarding_completed = TRUE,
        updated_at = NOW()
    WHERE id = p_psychologist_id;
  END IF;
  
  RETURN TRUE;
END;
$$;
COMMENT ON FUNCTION public.complete_onboarding_step(UUID, TEXT) IS 
'Marca um passo específico do onboarding como completo. Recalcula progresso e marca conclusão total se aplicável.';
-- =====================================================
-- 8. TRIGGER: Sincronizar pagamento com subscription_status
-- =====================================================

CREATE OR REPLACE FUNCTION public.sync_payment_step_with_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Quando subscription muda para active/trialing, marcar payment_step
  IF NEW.subscription_status IN ('active', 'trialing') THEN
    INSERT INTO public.psychologist_onboarding_state (psychologist_id, payment_step_completed)
    VALUES (NEW.id, TRUE)
    ON CONFLICT (psychologist_id) 
    DO UPDATE SET 
      payment_step_completed = TRUE,
      updated_at = NOW();
    
    -- Recalcular progresso
    PERFORM public.calculate_onboarding_progress(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;
-- Criar trigger (remover se existir para evitar duplicatas)
DROP TRIGGER IF EXISTS trg_sync_payment_step ON public.user_psychologists;
CREATE TRIGGER trg_sync_payment_step
  AFTER UPDATE OF subscription_status ON public.user_psychologists
  FOR EACH ROW
  WHEN (NEW.subscription_status IN ('active', 'trialing'))
  EXECUTE FUNCTION public.sync_payment_step_with_subscription();
COMMENT ON FUNCTION public.sync_payment_step_with_subscription() IS 
'Trigger que sincroniza o passo de pagamento quando a subscription fica ativa.';
-- =====================================================
-- 9. MIGRAÇÃO DE DADOS: Converter dados existentes
-- =====================================================

-- Para registros existentes, inferir estado dos passos baseado em dados existentes
DO $$
DECLARE
  v_record RECORD;
BEGIN
  FOR v_record IN 
    SELECT * FROM public.psychologist_onboarding_state 
    WHERE onboarding_completed_at IS NOT NULL 
       OR current_step > 1
  LOOP
    -- Se tem onboarding_completed_at, marcar todos os passos
    IF v_record.onboarding_completed_at IS NOT NULL THEN
      UPDATE public.psychologist_onboarding_state
      SET 
        payment_step_completed = TRUE,
        identity_step_completed = TRUE,
        professional_step_completed = TRUE,
        readiness_step_completed = TRUE,
        profile_step_completed = TRUE,
        total_steps = 5
      WHERE psychologist_id = v_record.psychologist_id;
    ELSE
      -- Inferir baseado no current_step anterior
      UPDATE public.psychologist_onboarding_state
      SET 
        payment_step_completed = v_record.current_step > 1 OR COALESCE(v_record.draft_data->>'plan_selected', 'false') = 'true',
        identity_step_completed = v_record.current_step > 2,
        professional_step_completed = v_record.current_step > 3,
        readiness_step_completed = v_record.current_step > 4,
        profile_step_completed = v_record.current_step > 5,
        total_steps = 5
      WHERE psychologist_id = v_record.psychologist_id;
    END IF;
    
    -- Recalcular progresso
    PERFORM public.calculate_onboarding_progress(v_record.psychologist_id);
  END LOOP;
END $$;
-- =====================================================
-- 10. PERMISSÕES RLS
-- =====================================================

-- Garantir RLS ativo
ALTER TABLE public.psychologist_onboarding_state ENABLE ROW LEVEL SECURITY;
-- Política para psicólogos verem/apenas seus próprios dados
DROP POLICY IF EXISTS "psychologist_onboarding_state_select_own" ON public.psychologist_onboarding_state;
CREATE POLICY "psychologist_onboarding_state_select_own" ON public.psychologist_onboarding_state
  FOR SELECT USING (auth.uid() = psychologist_id);
DROP POLICY IF EXISTS "psychologist_onboarding_state_insert_own" ON public.psychologist_onboarding_state;
CREATE POLICY "psychologist_onboarding_state_insert_own" ON public.psychologist_onboarding_state
  FOR INSERT WITH CHECK (auth.uid() = psychologist_id);
DROP POLICY IF EXISTS "psychologist_onboarding_state_update_own" ON public.psychologist_onboarding_state;
CREATE POLICY "psychologist_onboarding_state_update_own" ON public.psychologist_onboarding_state
  FOR UPDATE USING (auth.uid() = psychologist_id);
-- Permissões na view
GRANT SELECT ON public.psychologist_onboarding_summary TO authenticated;
-- =====================================================
-- 11. ÍNDICES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_onboarding_state_completion 
  ON public.psychologist_onboarding_state(onboarding_completed_at) 
  WHERE onboarding_completed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_onboarding_state_payment 
  ON public.psychologist_onboarding_state(payment_step_completed) 
  WHERE payment_step_completed = FALSE;
