-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-22T22:05:07Z

-- migration-created-via: supabase migration new
-- Schema sync: Remove tabelas obsoletas e garante tabelas de auditoria no PRD
-- Idempotent: pode rodar múltiplas vezes sem erro

-- =============================================================================
-- PARTE 1: Remover tabelas obsoletas (que foram para o lixo)
-- Essas tabelas existem no PRD mas não nas migrations atuais
-- =============================================================================

-- Tabela: catalog_interview_templates (obsoleta)
DROP TABLE IF EXISTS public.catalog_interview_templates CASCADE;

-- Tabela: sync_notifications (obsoleta)
DROP TABLE IF EXISTS public.sync_notifications CASCADE;

-- Tabela: webhook_failures (obsoleta)
DROP TABLE IF EXISTS public.webhook_failures CASCADE;

-- =============================================================================
-- PARTE 2: Criar tabelas de auditoria que podem estar faltando no PRD
-- =============================================================================

-- Tabela: calendar_change_log (auditoria de mudanças no calendário)
CREATE TABLE IF NOT EXISTS public.calendar_change_log (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    calendar_event_id uuid REFERENCES public.calendar_events(id) ON DELETE CASCADE,
    change_type text NOT NULL,
    changed_by uuid REFERENCES auth.users(id),
    old_values jsonb,
    new_values jsonb,
    created_at timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.calendar_change_log IS 'Audit log for calendar event changes';

-- RLS para calendar_change_log
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = 'calendar_change_log' 
        AND schemaname = 'public'
    ) THEN
        ALTER TABLE public.calendar_change_log ENABLE ROW LEVEL SECURITY;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Tabela: encryption_audit_log (auditoria de operações de criptografia)
CREATE TABLE IF NOT EXISTS public.encryption_audit_log (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    table_name text NOT NULL,
    record_id uuid,
    operation text NOT NULL,
    encrypted_by uuid REFERENCES auth.users(id),
    created_at timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.encryption_audit_log IS 'Audit log for encryption operations';

-- RLS para encryption_audit_log
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = 'encryption_audit_log' 
        AND schemaname = 'public'
    ) THEN
        ALTER TABLE public.encryption_audit_log ENABLE ROW LEVEL SECURITY;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Tabela: stripe_idempotency_log (controle de idempotência para webhooks Stripe)
CREATE TABLE IF NOT EXISTS public.stripe_idempotency_log (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    idempotency_key text UNIQUE NOT NULL,
    stripe_event_id text,
    event_type text,
    processed_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.stripe_idempotency_log IS 'Idempotency tracking for Stripe webhook processing';

-- RLS para stripe_idempotency_log
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = 'stripe_idempotency_log' 
        AND schemaname = 'public'
    ) THEN
        ALTER TABLE public.stripe_idempotency_log ENABLE ROW LEVEL SECURITY;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- =============================================================================
-- PARTE 3: Políticas de acesso para tabelas de auditoria
-- =============================================================================

-- Política para calendar_change_log (service_role only)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'calendar_change_log' 
        AND policyname = 'calendar_change_log_service_only'
    ) THEN
        CREATE POLICY calendar_change_log_service_only ON public.calendar_change_log
            FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Política para encryption_audit_log (service_role only)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'encryption_audit_log' 
        AND policyname = 'encryption_audit_log_service_only'
    ) THEN
        CREATE POLICY encryption_audit_log_service_only ON public.encryption_audit_log
            FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Política para stripe_idempotency_log (service_role only)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'stripe_idempotency_log' 
        AND policyname = 'stripe_idempotency_log_service_only'
    ) THEN
        CREATE POLICY stripe_idempotency_log_service_only ON public.stripe_idempotency_log
            FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
