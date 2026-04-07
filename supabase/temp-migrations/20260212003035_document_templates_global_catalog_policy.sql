-- ============================================================================
-- Migration: document_templates as global Fluri catalog
-- Purpose: keep templates public to all authenticated users (no psychologist ownership)
-- ============================================================================

BEGIN;
-- Ensure RLS is enabled and policy is explicitly global-read for app users.
ALTER TABLE public.document_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS document_templates_read ON public.document_templates;
DROP POLICY IF EXISTS "document_templates_read" ON public.document_templates;
DROP POLICY IF EXISTS document_templates_global_read ON public.document_templates;
DROP POLICY IF EXISTS "document_templates_global_read" ON public.document_templates;
CREATE POLICY document_templates_global_read
ON public.document_templates
FOR SELECT
TO authenticated
USING (true);
-- Normalize seeded Fluri templates as system catalog records.
UPDATE public.document_templates
SET created_by = NULL,
    updated_by = NULL
WHERE title IN (
  'Relatório Psicológico',
  'Relatório Multiprofissional',
  'Parecer Psicológico',
  'Laudo Psicológico',
  'Relato - Encaminhamento',
  'Declaração',
  'Declaração de Recebimento',
  'Atestado Psicológico (afastamento)',
  'Atestado Psicológico (apto)',
  'Contrato de Prestação de Serviço Psicológico - Presencial',
  'Contrato de Prestação de Serviços de Avaliação Psicológica'
);
COMMIT;
