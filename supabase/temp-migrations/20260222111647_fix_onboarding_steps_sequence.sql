-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T11:16:47Z
-- Corrigir sequência de passos do onboarding:
-- 1. Identity, 2. Professional, 3. Payment (Fase 1 - app access)
-- 4. Configuration (serviços, horários), 5. Profile (Fase 2 - completo)

-- =====================================================
-- PASSO 0: DESABILITAR TRIGGER TEMPORARIAMENTE
-- =====================================================
ALTER TABLE psychologist_onboarding_state DISABLE TRIGGER trg_update_onboarding_progress;
-- =====================================================
-- PASSO 1: RENOMEAR COLUNA readiness -> configuration
-- =====================================================

-- Renomear a coluna readiness_step_completed para configuration_step_completed
ALTER TABLE psychologist_onboarding_state 
RENAME COLUMN readiness_step_completed TO configuration_step_completed;
-- =====================================================
-- PASSO 2: RECRIAR A FUNÇÃO complete_onboarding_step
-- =====================================================

CREATE OR REPLACE FUNCTION public.complete_onboarding_step(
  p_step text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_psychologist_id uuid;
BEGIN
  -- Obter o psychologist_id do usuário atual
  SELECT psychologist_id INTO v_psychologist_id
  FROM user_psychologists
  WHERE user_id = auth.uid();
  
  IF v_psychologist_id IS NULL THEN
    RAISE EXCEPTION 'Psychologist not found for current user';
  END IF;
  
  -- Marcar o passo específico como completo
  CASE p_step
    WHEN 'identity' THEN
      UPDATE psychologist_onboarding_state 
      SET identity_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    WHEN 'professional' THEN
      UPDATE psychologist_onboarding_state 
      SET professional_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    WHEN 'payment' THEN
      UPDATE psychologist_onboarding_state 
      SET payment_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    WHEN 'configuration' THEN
      UPDATE psychologist_onboarding_state 
      SET configuration_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    WHEN 'profile' THEN
      UPDATE psychologist_onboarding_state 
      SET profile_step_completed = true
      WHERE psychologist_id = v_psychologist_id;
    
    ELSE
      RAISE EXCEPTION 'Unknown onboarding step: %', p_step;
  END CASE;
  
  RETURN true;
END;
$$;
COMMENT ON FUNCTION public.complete_onboarding_step(text) IS 
'Marca um passo específico do onboarding como completo.
Passos: identity → professional → payment → configuration → profile';
-- =====================================================
-- PASSO 3: RECRIAR A FUNÇÃO calculate_onboarding_progress
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_onboarding_progress(p_psychologist_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_completed_steps INTEGER := 0;
  v_state RECORD;
BEGIN
  -- Obter estado atual uma única vez
  SELECT 
    identity_step_completed,
    professional_step_completed,
    payment_step_completed,
    configuration_step_completed,
    profile_step_completed
  INTO v_state
  FROM psychologist_onboarding_state 
  WHERE psychologist_id = p_psychologist_id;
  
  -- Contar passos completos (5 passos, 20% cada)
  IF v_state.identity_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.professional_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.payment_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.configuration_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  IF v_state.profile_step_completed THEN v_completed_steps := v_completed_steps + 1; END IF;
  
  RETURN (v_completed_steps * 100) / 5;
END;
$$;
COMMENT ON FUNCTION public.calculate_onboarding_progress(uuid) IS 
'Calcula a porcentagem de progresso baseado em 5 passos (20% cada)';
-- =====================================================
-- PASSO 4: ATUALIZAR O TRIGGER QUE CALCULA PROGRESSO
-- =====================================================

DROP TRIGGER IF EXISTS trg_update_onboarding_progress ON psychologist_onboarding_state;
CREATE OR REPLACE FUNCTION public.update_onboarding_progress()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_progress INTEGER;
  v_new_step INTEGER;
BEGIN
  -- Calculate progress
  v_progress := calculate_onboarding_progress(NEW.psychologist_id);
  
  -- Determine current step based on completion status
  -- Order: identity (1) → professional (2) → payment (3) → configuration (4) → profile (5)
  IF NOT NEW.identity_step_completed THEN
    v_new_step := 1;
  ELSIF NOT NEW.professional_step_completed THEN
    v_new_step := 2;
  ELSIF NOT NEW.payment_step_completed THEN
    v_new_step := 3;
  ELSIF NOT NEW.configuration_step_completed THEN
    v_new_step := 4;
  ELSIF NOT NEW.profile_step_completed THEN
    v_new_step := 5;
  ELSE
    v_new_step := 6; -- complete
  END IF;
  
  -- Update calculated fields only if changed
  IF NEW.completion_percentage IS DISTINCT FROM v_progress 
     OR NEW.current_step IS DISTINCT FROM v_new_step THEN
    NEW.completion_percentage := v_progress;
    NEW.current_step := v_new_step;
  END IF;
  
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_update_onboarding_progress
  BEFORE INSERT OR UPDATE ON psychologist_onboarding_state
  FOR EACH ROW
  EXECUTE FUNCTION update_onboarding_progress();
-- =====================================================
-- PASSO 5: RECRIAR A VIEW psychologist_onboarding_status
-- =====================================================

CREATE OR REPLACE VIEW public.psychologist_onboarding_status AS
SELECT 
  psychologist_id,
  current_step,
  completion_percentage,
  total_steps,
  -- Passos individuais
  identity_step_completed,
  professional_step_completed,
  payment_step_completed,
  configuration_step_completed,
  profile_step_completed,
  -- Flags de fase
  (identity_step_completed AND professional_step_completed AND payment_step_completed) AS essential_complete,
  (identity_step_completed AND professional_step_completed AND payment_step_completed AND configuration_step_completed AND profile_step_completed) AS fully_complete,
  -- Status
  CASE 
    WHEN onboarding_completed_at IS NOT NULL THEN 'completed'
    WHEN identity_step_completed AND professional_step_completed AND payment_step_completed THEN 'in_progress'
    ELSE 'pending'
  END AS status,
  onboarding_completed_at,
  last_resumed_at,
  abandoned_at
FROM psychologist_onboarding_state;
COMMENT ON VIEW public.psychologist_onboarding_status IS 
'Status consolidado do onboarding com sequência correta: identity → professional → payment → configuration → profile';
-- =====================================================
-- PASSO 6: ATUALIZAR A FUNÇÃO can_user_access_app
-- =====================================================

CREATE OR REPLACE FUNCTION public.can_user_access_app()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_psychologist_id uuid;
  v_state RECORD;
BEGIN
  -- Obter o psychologist_id do usuário atual
  SELECT psychologist_id INTO v_psychologist_id
  FROM user_psychologists
  WHERE user_id = auth.uid();
  
  IF v_psychologist_id IS NULL THEN
    RETURN false;
  END IF;
  
  -- Verificar se os passos essenciais estão completos (identity, professional, payment)
  SELECT 
    identity_step_completed,
    professional_step_completed,
    payment_step_completed
  INTO v_state
  FROM psychologist_onboarding_state
  WHERE psychologist_id = v_psychologist_id;
  
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  
  RETURN v_state.identity_step_completed 
     AND v_state.professional_step_completed 
     AND v_state.payment_step_completed;
END;
$$;
COMMENT ON FUNCTION public.can_user_access_app() IS 
'Verifica se o usuário pode acessar o app (passos essenciais: identity + professional + payment)';
-- =====================================================
-- PASSO 7: ATUALIZAR A FUNÇÃO get_onboarding_status_v2
-- =====================================================

-- Dropar e recriar porque o tipo de retorno mudou (readiness → configuration)
DROP FUNCTION IF EXISTS public.get_onboarding_status_v2(UUID);
CREATE FUNCTION public.get_onboarding_status_v2(p_user_id UUID DEFAULT NULL)
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
  configuration_completed BOOLEAN,
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
    pos.configuration_step_completed,
    pos.profile_step_completed
  FROM public.psychologist_onboarding_summary pos
  WHERE pos.psychologist_id = v_user_id;
END;
$$;
COMMENT ON FUNCTION public.get_onboarding_status_v2(UUID) IS 
'Retorna o status completo do onboarding do usuário (v2: usa configuration em vez de readiness)';
-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_onboarding_status_v2(UUID) TO authenticated;
-- =====================================================
-- PASSO 8: ATUALIZAR A VIEW psychologist_onboarding_summary
-- =====================================================

-- Dropar e recriar porque o tipo de retorno mudou (readiness → configuration)
DROP VIEW IF EXISTS public.psychologist_onboarding_summary;
CREATE VIEW public.psychologist_onboarding_summary AS
SELECT 
  pos.psychologist_id,
  pos.payment_step_completed,
  pos.identity_step_completed,
  pos.professional_step_completed,
  pos.configuration_step_completed,
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
      AND pos.configuration_step_completed 
      AND pos.profile_step_completed
    ) AS fully_complete,
  -- Próximo passo pendente (para redirecionamento)
  CASE 
    WHEN pos.onboarding_completed_at IS NOT NULL THEN NULL
    WHEN NOT pos.payment_step_completed THEN 'subscription'
    WHEN NOT pos.identity_step_completed THEN 'identity'
    WHEN NOT pos.professional_step_completed THEN 'professional'
    WHEN NOT pos.configuration_step_completed THEN 'configuration'
    WHEN NOT pos.profile_step_completed THEN 'profile'
    ELSE NULL
  END AS next_pending_step,
  up.subscription_status
FROM public.psychologist_onboarding_state pos
LEFT JOIN public.user_psychologists up ON up.id = pos.psychologist_id;
COMMENT ON VIEW public.psychologist_onboarding_summary IS 
'View consolidada com resumo do estado de onboarding (v2: usa configuration em vez de readiness)';
-- Grant select permission
GRANT SELECT ON public.psychologist_onboarding_summary TO authenticated;
-- =====================================================
-- PASSO 10: ATUALIZAR DADOS EXISTENTES (migrar readiness → configuration)
-- =====================================================

-- Qualquer dado que tenha readiness como true, agora é configuration
-- (mas como renameamos a coluna, os dados já estão lá)

-- =====================================================
-- PASSO 11: REABILITAR TRIGGER
-- =====================================================
ALTER TABLE psychologist_onboarding_state ENABLE TRIGGER trg_update_onboarding_progress;
-- Resetar o cache de permissões
NOTIFY pgrst, 'reload schema';
