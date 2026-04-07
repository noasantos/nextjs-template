-- migration-created-via: pnpm supabase:migration:new
-- Cria tabelas session_types e clinical_session_details que faltam no PRD
-- Atualizado para usar psychologist_patient_id (padrão atual)
-- Idempotent: pode rodar múltiplas vezes sem erro

-- =============================================================================
-- TABELA: session_types
-- Catálogo de tipos de sessão disponíveis
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.session_types (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    code text UNIQUE,
    name text NOT NULL DEFAULT 'Sessao',
    default_duration_minutes integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

COMMENT ON TABLE public.session_types IS 'Catalog of available session types';

-- RLS para session_types
DO $$
BEGIN
    ALTER TABLE public.session_types ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Política: todos os usuários autenticados podem ver
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'session_types' 
        AND policyname = 'session_types_select_all'
    ) THEN
        CREATE POLICY session_types_select_all ON public.session_types
            FOR SELECT TO authenticated USING (true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Trigger para updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'session_types_updated_at'
    ) THEN
        CREATE TRIGGER session_types_updated_at
            BEFORE UPDATE ON public.session_types
            FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Note: Session types seed data has been moved to supabase/seed.sql (reference values section)
-- under the 'psychological_service_type' category.
-- The reference_values table is the canonical source for service/session type definitions.
-- This migration only creates the session_types table structure for backward compatibility.

-- =============================================================================
-- TABELA: clinical_session_details
-- Detalhes adicionais das sessões clínicas
-- Usa psychologist_patient_id (padrão atual após renomeação)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.clinical_session_details (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    calendar_event_id uuid NOT NULL REFERENCES public.calendar_events(id) ON DELETE CASCADE,
    psychologist_patient_id uuid REFERENCES public.psychologist_patients(id) ON DELETE SET NULL,
    psychologist_service_id uuid REFERENCES public.psychologist_services(id) ON DELETE SET NULL,
    patient_id uuid NOT NULL REFERENCES public.user_patients(id) ON DELETE CASCADE,
    session_type_id uuid REFERENCES public.session_types(id) ON DELETE SET NULL,
    session_number integer,
    clinical_session_id uuid REFERENCES public.psychologist_clinical_sessions(id) ON DELETE SET NULL,
    attendance_confirmed boolean DEFAULT false,
    confirmation_sent_at timestamp with time zone,
    reminder_sent_at timestamp with time zone,
    billing_status text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT unique_event_session UNIQUE (calendar_event_id)
);

COMMENT ON TABLE public.clinical_session_details IS 'Additional clinical details for therapy sessions';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_session_details_event ON public.clinical_session_details(calendar_event_id);
CREATE INDEX IF NOT EXISTS idx_session_details_patient ON public.clinical_session_details(patient_id);
CREATE INDEX IF NOT EXISTS idx_session_details_clinical ON public.clinical_session_details(clinical_session_id) WHERE clinical_session_id IS NOT NULL;

-- RLS para clinical_session_details
DO $$
BEGIN
    ALTER TABLE public.clinical_session_details ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Política: psicólogos podem gerenciar via evento do calendário
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'clinical_session_details' 
        AND policyname = 'clinical_session_details_psychologist_access'
    ) THEN
        CREATE POLICY clinical_session_details_psychologist_access ON public.clinical_session_details
            FOR ALL TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.calendar_events e
                    WHERE e.id = calendar_event_id AND e.psychologist_id = auth.uid()
                )
            )
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM public.calendar_events e
                    WHERE e.id = calendar_event_id AND e.psychologist_id = auth.uid()
                )
            );
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Trigger para updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'clinical_session_details_updated_at'
    ) THEN
        CREATE TRIGGER clinical_session_details_updated_at
            BEFORE UPDATE ON public.clinical_session_details
            FOR EACH ROW EXECUTE FUNCTION moddatetime('updated_at');
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
