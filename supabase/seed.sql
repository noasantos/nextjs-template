-- =============================================================================
-- supabase/seed.sql — single file loaded after migrations (`supabase db reset`).
-- Config: `config.toml` → [db.seed].sql_paths = ["./seed.sql"].
-- Former `supabase/seeds/*.sql` sections are preserved in order below.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 000 — app_roles catalog (FK for public.user_roles.role)
-- -----------------------------------------------------------------------------
-- Baseline migrations define `public.app_roles` (text PK) + `public.user_roles.role`
-- referencing it. Seed the catalog before any `user_roles` inserts (tests + local UX).
-- Product code also uses the legacy `public.app_role` enum on domain tables; keep
-- slugs aligned where both exist.
INSERT INTO public.app_roles (role, label, is_self_sign_up_allowed)
VALUES
  ('admin', 'Administrator', false),
  ('user', 'User', true),
  ('psychologist', 'Psychologist', true),
  ('patient', 'Patient', true),
  ('assistant', 'Assistant', true)
ON CONFLICT (role) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 001 — Storage buckets
-- -----------------------------------------------------------------------------
-- ============================================================================
-- Seed: Storage Buckets
-- Description: Creates required storage buckets for application assets
-- Order: 001 (must run first - activities depend on these buckets)
-- ============================================================================

-- Activity assets buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'activity-images',
    'activity-images',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'activity-pdfs',
    'activity-pdfs',
    false,
    10485760,
    ARRAY['application/pdf']
  )
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = NOW();

-- -----------------------------------------------------------------------------
-- 002 — Reference values
-- -----------------------------------------------------------------------------
-- ============================================================================
-- Seed: Reference Values
-- Description: Core reference data for the application
-- Order: 002 (no dependencies)
-- Includes: Cancellation policies, specialties, approaches, service types,
--           financial transaction categories
-- ============================================================================

INSERT INTO public.reference_values (category, label_pt, value, metadata, is_active)
VALUES
  -- ==========================================================================
  -- 1. CANCELLATION POLICIES
  -- ==========================================================================
  (
    'cancellation_policy',
    'Flexível',
    'flexible',
    '{"fee_percentage": 0, "min_notice_hours": 24, "description": "Cancelamento gratuito até 24h antes da sessão"}'::jsonb,
    true
  ),
  (
    'cancellation_policy',
    'Padrão',
    'standard',
    '{"fee_percentage": 50, "min_notice_hours": 24, "description": "Taxa de 50% se cancelado menos de 24h antes"}'::jsonb,
    true
  ),
  (
    'cancellation_policy',
    'Rigorosa',
    'strict',
    '{"fee_percentage": 100, "min_notice_hours": 48, "description": "Taxa de 100% se cancelado menos de 48h antes"}'::jsonb,
    true
  ),
  (
    'cancellation_policy',
    'Não Reembolsável',
    'non_refundable',
    '{"fee_percentage": 100, "min_notice_hours": 0, "description": "Taxa de 100% para qualquer cancelamento"}'::jsonb,
    true
  ),

  -- ==========================================================================
  -- 2. PSYCHOLOGY SPECIALTIES (CFP recognized)
  -- ==========================================================================
  ('specialty', 'Psicologia Clínica', 'clinical_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia do Trabalho', 'work_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia Escolar/Educacional', 'school_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia Social', 'social_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia do Esporte', 'sport_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia Jurídica', 'forensic_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia da Saúde', 'health_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia Hospitalar', 'hospital_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia Organizacional', 'organizational_psychology', '{}'::jsonb, true),
  ('specialty', 'Psicologia do Trânsito', 'traffic_psychology', '{}'::jsonb, true),

  -- ==========================================================================
  -- 3. PSYCHOLOGICAL APPROACHES
  -- ==========================================================================
  ('approach', 'Psicanálise', 'psychoanalysis', '{}'::jsonb, true),
  ('approach', 'Terapia Cognitivo-Comportamental (TCC)', 'cbt', '{}'::jsonb, true),
  ('approach', 'Análise do Comportamento (Behaviorismo)', 'behaviorism', '{}'::jsonb, true),
  ('approach', 'Gestalt-terapia', 'gestalt', '{}'::jsonb, true),
  ('approach', 'Humanismo', 'humanism', '{}'::jsonb, true),
  ('approach', 'Terapia Analítico-Comportamental (TAC)', 'tac', '{}'::jsonb, true),
  ('approach', 'Terapia de Aceitação e Compromisso (ACT)', 'act_therapy', '{}'::jsonb, true),
  ('approach', 'Dialética Comportamental (DBT)', 'dbt', '{}'::jsonb, true),
  ('approach', 'Terapia Esquema', 'schema_therapy', '{}'::jsonb, true),
  ('approach', 'Psicodrama', 'psychodrama', '{}'::jsonb, true),
  ('approach', 'Terapia Familiar Sistêmica', 'family_systemic', '{}'::jsonb, true),
  ('approach', 'Ludoterapia', 'play_therapy', '{}'::jsonb, true),
  ('approach', 'Abordagem Integrativa', 'integrative', '{}'::jsonb, true),

  -- ==========================================================================
  -- 4. PSYCHOLOGICAL SERVICE TYPES
  -- ==========================================================================
  ('psychological_service_type', 'Sessão Individual - Adulto', 'individual_adult',
   '{"default_duration_minutes": 50}'::jsonb, true),
  ('psychological_service_type', 'Sessão Individual - Criança/Adolescente', 'individual_child',
   '{"default_duration_minutes": 50}'::jsonb, true),
  ('psychological_service_type', 'Sessão de Casal', 'couple',
   '{"default_duration_minutes": 60}'::jsonb, true),
  ('psychological_service_type', 'Sessão Familiar', 'family',
   '{"default_duration_minutes": 90}'::jsonb, true),
  ('psychological_service_type', 'Sessão de Grupo', 'group',
   '{"default_duration_minutes": 90}'::jsonb, true),
  ('psychological_service_type', 'Supervisão', 'supervision',
   '{"default_duration_minutes": 60}'::jsonb, true),
  ('psychological_service_type', 'Plantão Psicológico', 'psychological_duty',
   '{"default_duration_minutes": 30}'::jsonb, true),
  ('psychological_service_type', 'Avaliação Psicológica', 'assessment',
   '{"default_duration_minutes": 90}'::jsonb, true),

  -- ==========================================================================
  -- 5. FINANCIAL TRANSACTION CATEGORIES (Income)
  -- ==========================================================================
  ('financial_transaction_category', 'Consulta Presencial', 'in_person_session',
   '{"type": "income"}'::jsonb, true),
  ('financial_transaction_category', 'Consulta Online', 'online_session',
   '{"type": "income"}'::jsonb, true),
  ('financial_transaction_category', 'Supervisão', 'supervision_income',
   '{"type": "income"}'::jsonb, true),
  ('financial_transaction_category', 'Plantão Psicológico', 'psychological_duty_income',
   '{"type": "income"}'::jsonb, true),
  ('financial_transaction_category', 'Avaliação Psicológica', 'psychological_assessment_income',
   '{"type": "income"}'::jsonb, true),
  ('financial_transaction_category', 'Bateria de Testes', 'test_battery',
   '{"type": "income"}'::jsonb, true),
  ('financial_transaction_category', 'Orientação de Pais', 'parent_guidance',
   '{"type": "income"}'::jsonb, true),
  ('financial_transaction_category', 'Outros Serviços', 'other_services',
   '{"type": "income"}'::jsonb, true),

  -- ==========================================================================
  -- 6. FINANCIAL TRANSACTION CATEGORIES (Expense)
  -- ==========================================================================
  ('financial_transaction_category', 'Aluguel do Consultório', 'office_rent',
   '{"type": "expense"}'::jsonb, true),
  ('financial_transaction_category', 'Software/Plataforma', 'software_subscription',
   '{"type": "expense"}'::jsonb, true),
  ('financial_transaction_category', 'Material de Escritório', 'office_supplies',
   '{"type": "expense"}'::jsonb, true),
  ('financial_transaction_category', 'Marketing/Divulgação', 'marketing',
   '{"type": "expense"}'::jsonb, true),
  ('financial_transaction_category', 'Capacitação/Cursos', 'training_courses',
   '{"type": "expense"}'::jsonb, true),
  ('financial_transaction_category', 'Supervisão Recebida', 'received_supervision',
   '{"type": "expense"}'::jsonb, true),
  ('financial_transaction_category', 'Transporte', 'transportation',
   '{"type": "expense"}'::jsonb, true),
  ('financial_transaction_category', 'Impostos', 'taxes',
   '{"type": "expense"}'::jsonb, true),
  ('financial_transaction_category', 'Outras Despesas', 'other_expenses',
   '{"type": "expense"}'::jsonb, true)

ON CONFLICT (category, value) DO UPDATE
SET
  label_pt = EXCLUDED.label_pt,
  metadata = EXCLUDED.metadata,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- -----------------------------------------------------------------------------
-- 003 — Clinical activities catalog
-- -----------------------------------------------------------------------------
-- ============================================================================
-- Seed: Clinical Activities Catalog
-- Description: Therapy activities and worksheets for patient assignments
-- Order: 003 (depends on 001_storage_buckets for media paths)
-- ============================================================================

INSERT INTO public.catalog_clinical_activities (
  code,
  name,
  title,
  description,
  active,
  image_path,
  pdf_path,
  activity_kind,
  duration_min,
  goals,
  populations,
  delivery_modes,
  tags,
  clinician_notes_template,
  risk_level
)
VALUES
  (
    'registro-pensamentos-distorcidos',
    'Registro de Pensamentos Distorcidos',
    'Registro de Pensamentos Distorcidos',
    'Esta atividade ajuda a identificar pensamentos automáticos que surgem em situações emocionalmente difíceis. O objetivo é aumentar a consciência sobre como esses pensamentos influenciam emoções e comportamentos, abrindo espaço para respostas mais equilibradas e conscientes.',
    true,
    'activity-images/registro-pensamentos-distorcidos.jpg',
    'activity-pdfs/registro-pensamentos-distorcidos.pdf',
    'worksheet',
    30,
    ARRAY['Identificar pensamentos automáticos', 'Aumentar consciência emocional', 'Desenvolver respostas equilibradas'],
    ARRAY['Adultos', 'Adolescentes'],
    ARRAY['in_person', 'telehealth'],
    ARRAY['TCC', 'pensamentos automáticos', 'registro', 'worksheet'],
    'Observar padrões de pensamento distorcido e progresso na identificação de cognições automáticas.',
    'low'
  ),
  (
    'analise-custo-beneficio',
    'Análise de Custo-Benefício',
    'Análise de Custo-Benefício',
    'Ferramenta de reflexão para avaliar decisões ou comportamentos de forma mais ampla. Aqui, você considera benefícios e dificuldades no curto, médio e longo prazo, favorecendo escolhas alinhadas com seus objetivos e com o cuidado consigo.',
    true,
    'activity-images/analise-custo-beneficio.jpg',
    'activity-pdfs/analise-custo-beneficio.pdf',
    'worksheet',
    45,
    ARRAY['Avaliar decisões de forma ampla', 'Considerar prazos diferentes', 'Alinhar escolhas com objetivos'],
    ARRAY['Adultos', 'Adolescentes'],
    ARRAY['in_person', 'telehealth'],
    ARRAY['TCC', 'tomada de decisão', 'análise', 'worksheet'],
    'Avaliar a qualidade da análise e evolução na tomada de decisões conscientes.',
    'low'
  ),
  (
    'roda-dos-valores',
    'Roda dos Valores',
    'Roda dos Valores',
    'Atividade voltada para identificar valores importantes em diferentes áreas da vida e perceber o quanto eles estão presentes no seu cotidiano. O foco não é julgamento, mas clareza e orientação para pequenos ajustes possíveis.',
    true,
    'activity-images/roda-dos-valores.jpg',
    'activity-pdfs/roda-dos-valores.pdf',
    'worksheet',
    40,
    ARRAY['Identificar valores pessoais', 'Avaliar presença nos diferentes contextos', 'Orientar ajustes na vida'],
    ARRAY['Adultos', 'Adolescentes'],
    ARRAY['in_person', 'telehealth'],
    ARRAY['ACT', 'valores', 'worksheet', 'autoconhecimento'],
    'Observar clareza sobre valores e progresso em alinhar comportamentos a eles.',
    'low'
  ),
  (
    'diario-atividades-prazerosas',
    'Diário de Atividades Prazerosas',
    'Diário de Atividades Prazerosas',
    'Este diário apoia o engajamento em atividades que promovem prazer e bem-estar. A proposta é observar como pequenas ações impactam seu humor, emoções e sensação de vitalidade ao longo do tempo.',
    true,
    'activity-images/diario-atividades-prazerosas.jpg',
    'activity-pdfs/diario-atividades-prazerosas.pdf',
    'diary',
    20,
    ARRAY['Aumentar engajamento em atividades prazerosas', 'Observar impacto no humor', 'Promover bem-estar'],
    ARRAY['Adultos', 'Adolescentes', 'Idosos'],
    ARRAY['in_person', 'telehealth'],
    ARRAY['Ativação Comportamental', 'diário', 'bem-estar', 'humor'],
    'Monitorar frequência de atividades prazerosas e correlação com variações de humor.',
    'low'
  ),
  (
    'matriz-de-prioridades',
    'Matriz de Prioridades',
    'Matriz de Prioridades',
    'Ferramenta de organização que auxilia a diferenciar o que é urgente do que é importante. Ajuda a reduzir a sensação de sobrecarga, apoiar o planejamento e direcionar energia para o que realmente precisa de atenção no momento.',
    true,
    'activity-images/matriz-de-prioridades.jpg',
    'activity-pdfs/matriz-de-prioridades.pdf',
    'worksheet',
    35,
    ARRAY['Diferenciar urgente de importante', 'Reduzir sobrecarga', 'Apoiar planejamento'],
    ARRAY['Adultos', 'Adolescentes'],
    ARRAY['in_person', 'telehealth'],
    ARRAY['organização', 'planejamento', 'worksheet', 'produtividade'],
    'Avaliar uso efetivo da matriz e redução de comportamentos de procrastinação.',
    'low'
  ),
  (
    'cartao-diario-dbt',
    'Cartão Diário DBT',
    'Cartão Diário DBT',
    'Ferramenta da Terapia Dialética Comportamental para registro diário de emoções, pensamentos e comportamentos. Auxilia no desenvolvimento de habilidades de regulação emocional e mindfulness.',
    true,
    'activity-images/cartao-diario-dbt.jpg',
    'activity-pdfs/cartao-diario-dbt.pdf',
    'diary',
    25,
    ARRAY['Regulação emocional', 'Mindfulness', 'Atenção plena', 'Identificação de padrões'],
    ARRAY['Adultos', 'Adolescentes'],
    ARRAY['in_person', 'telehealth'],
    ARRAY['DBT', 'regulação emocional', 'diário', 'mindfulness'],
    'Observar padrões emocionais e uso de habilidades DBT em situações desafiadoras.',
    'medium'
  )

ON CONFLICT (code) DO UPDATE
SET
  name = EXCLUDED.name,
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  active = EXCLUDED.active,
  image_path = EXCLUDED.image_path,
  pdf_path = EXCLUDED.pdf_path,
  activity_kind = EXCLUDED.activity_kind,
  duration_min = EXCLUDED.duration_min,
  goals = EXCLUDED.goals,
  populations = EXCLUDED.populations,
  delivery_modes = EXCLUDED.delivery_modes,
  tags = EXCLUDED.tags,
  clinician_notes_template = EXCLUDED.clinician_notes_template,
  risk_level = EXCLUDED.risk_level,
  updated_at = NOW();

-- -----------------------------------------------------------------------------
-- 004 — Document templates (base + additional CRP templates)
-- -----------------------------------------------------------------------------
-- ============================================================================
-- Seed: Document Templates
-- Description: Psychology report templates (CRP compliant)
-- Order: 004 (no dependencies)
-- Note: Uses deterministic UUIDs for idempotent inserts
-- ============================================================================

-- Template 1: Relatório Psicológico
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a01'::uuid,
  'Relatório Psicológico',
  'Template CRP para relatório psicológico completo com identificação, demanda, procedimento, análise e conclusão',
  'report',
  '{"version":"1.0","metadata":{"category":"report","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"RELATÓRIO PSICOLÓGICO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"IDENTIFICAÇÃO","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"Interessado: {{patient.fullName}} (Idade: {{patient.age}}, Gênero: {{patient.gender}}, Estado Civil: {{patient.maritalStatus}}, Escolaridade: {{patient.educationLevel}})","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Nome da(o) solicitante: identificação de quem solicitou o documento, especificando se a solicitação foi realizada pelo Poder Judiciário, por empresas, instituições públicas ou privadas, pela(o) própria(o) usuária(o) do processo de trabalho prestado ou por outras(os) interessadas(os);","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Finalidade: descrição da razão ou motivo do pedido;","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Nome da(o) autora(or): {{psychologist.fullName}} - {{psychologist.crpFull}}.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"DESCRIÇÃO DA DEMANDA","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"Descrever as informações sobre o que motivou a busca pelo processo de trabalho prestado, indicando quem forneceu as informações e as demandas que levaram à solicitação do documento.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}'::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();

-- Template 2: Relatório Multiprofissional
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a02'::uuid,
  'Relatório Multiprofissional',
  'Template CRP para relatório multiprofissional com contribuições de diferentes especialistas',
  'report',
  '{"version":"1.0","metadata":{"category":"report","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"RELATÓRIO MULTIPROFISSIONAL","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"IDENTIFICAÇÃO","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"Interessado: {{patient.fullName}} (Idade: {{patient.age}}, Gênero: {{patient.gender}}, Estado Civil: {{patient.maritalStatus}}, Escolaridade: {{patient.educationLevel}})","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"DESCRIÇÃO DA DEMANDA","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"Descrever as informações sobre o que motivou a busca pelo processo de trabalho multiprofissional, indicando quem forneceu as informações e as demandas que levaram à solicitação do documento.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"PROCEDIMENTO","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"Apresentar o raciocínio e recursos técnico-científicos que justificam o processo de trabalho pela(o) psicóloga(o) e/ou pela equipe multiprofissional.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"ANÁLISE","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"Orienta-se que cada profissional faça sua análise separadamente, identificando, com subtítulo, o nome e a categoria profissional.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}'::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();

-- Template 3: Parecer Psicológico
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a03'::uuid,
  'Parecer Psicológico',
  'Template CRP para parecer psicológico - análise técnica sobre documentos recebidos',
  'report',
  $td3${"version":"1.0","metadata":{"category":"report","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"PARECER PSICOLÓGICO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"IDENTIFICAÇÃO","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"Interessado: {{patient.fullName}} (Idade: {{patient.age}}, Gênero: {{patient.gender}}, Estado Civil: {{patient.maritalStatus}}, Escolaridade: {{patient.educationLevel}})","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Finalidade: Análise técnica e ética a respeito do Laudo Psicológico recebido pelo solicitante assim como do processo de Avaliação Psicológica ao qual o mesmo submeteu na referida instituição.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Nome da(o) autora(or): {{psychologist.fullName}} - {{psychologist.crpFull}}.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"FUNDAMENTAÇÃO TEÓRICA E METODOLÓGICA","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"ANÁLISE TÉCNICA","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"PARECER","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td3$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();
-- Template 4: Laudo Psicológico
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a04'::uuid,
  'Laudo Psicológico',
  'Template CRP para laudo psicológico completo com identificação, procedimentos e conclusão',
  'report',
  $td4${"version":"1.0","metadata":{"category":"report","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"LAUDO PSICOLÓGICO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"IDENTIFICAÇÃO","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"Interessado: {{patient.fullName}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Data de nascimento: {{patient.dateOfBirth}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Idade: {{patient.age}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"CPF: {{patient.cpf}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Escolaridade: {{patient.educationLevel}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"PROCEDIMENTOS","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"RESULTADOS","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"list","listType":"number","children":[{"type":"listitem","children":[{"type":"text","text":"CONCLUSÃO","format":0,"version":1}],"value":1,"version":1}],"version":1},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td4$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();
-- Template 5: Relato - Encaminhamento
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a05'::uuid,
  'Relato - Encaminhamento',
  'Template para relato de encaminhamento com identificação, queixa principal e hipóteses',
  'referral',
  $td5${"version":"1.0","metadata":{"category":"referral","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"RELATO - ENCAMINHAMENTO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"IDENTIFICAÇÃO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Nome: {{patient.fullName}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Idade: {{patient.age}} Gênero: {{patient.gender}} Ocupação: {{patient.profession}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Escolaridade: {{patient.educationLevel}} Estado civil: {{patient.maritalStatus}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"QUEIXA PRINCIPAL","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"HISTÓRICO BREVE","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"HIPÓTESES DIAGNÓSTICAS","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"ENCAMINHAMENTO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td5$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();
-- Template 6: Declaração
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a06'::uuid,
  'Declaração',
  'Template para declaração de comparecimento',
  'declaration',
  $td6${"version":"1.0","metadata":{"category":"declaration","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"DECLARAÇÃO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Declaro, para fins de (especificar o fim), que {{patient.fullName}}, portador(a) do RG nº {{patient.rg}} e CPF nº {{patient.cpf}} compareceu a este consultório para atendimento psicológico na data de hoje, das ____ às ____ h.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"_______________________________","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td6$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();
-- Template 7: Declaração de Recebimento
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a07'::uuid,
  'Declaração de Recebimento',
  'Template para declaração de recebimento de laudo',
  'declaration',
  $td7${"version":"1.0","metadata":{"category":"declaration","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"DECLARAÇÃO DE RECEBIMENTO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Eu, {{patient.fullName}}, portador(a) da carteira de identidade nº {{patient.rg}}, declaro que recebi 01 (uma) via do Laudo Psicológico referente à Avaliação Psicológica realizada.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"_______________________________","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Assinatura do Paciente","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td7$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();
-- Template 8: Atestado Psicológico (Afastamento)
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a08'::uuid,
  'Atestado Psicológico (Afastamento)',
  'Template para atestado psicológico de afastamento',
  'certificate',
  $td8${"version":"1.0","metadata":{"category":"certificate","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"ATESTADO PSICOLÓGICO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Atesto que {{patient.fullName}}, portador(a) do RG nº {{patient.rg}} e CPF nº {{patient.cpf}}, necessita de afastamento de suas atividades laborais por período determinado, por apresentar quadro que demanda atenção psicológica.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Período de afastamento: ___ dias","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td8$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();
-- Template 9: Atestado Psicológico (Apto)
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a09'::uuid,
  'Atestado Psicológico (Apto)',
  'Template para atestado psicológico de aptidão',
  'certificate',
  $td9${"version":"1.0","metadata":{"category":"certificate","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"ATESTADO PSICOLÓGICO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"Atesto que {{patient.fullName}}, portador(a) do RG nº {{patient.rg}} e CPF nº {{patient.cpf}}, apresenta adequadas condições psicológicas para exercer as atividades profissionais e/ou ocupacionais correspondentes à sua função, sendo considerado APTO.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"As características psicológicas avaliadas encontram-se dentro de limites adequados para o exercício das atividades demandadas.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td9$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();
-- Template 10: Contrato de Prestação de Serviço (Presencial)
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a10'::uuid,
  'Contrato de Prestação de Serviço Psicológico - Presencial',
  'Template de contrato de prestação de serviço psicológico presencial',
  'contract',
  $td10${"version":"1.0","metadata":{"category":"contract","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"CONTRATO DE PRESTAÇÃO DE SERVIÇO PSICOLÓGICO NA MODALIDADE PRESENCIAL","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DAS PARTES","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"PSICÓLOGO(A): {{psychologist.fullName}}, inscrito(a) no CPF sob nº {{psychologist.cpf}}, com inscrição profissional no Conselho Regional de Psicologia {{psychologist.crpFull}}.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"PACIENTE: {{patient.fullName}}, inscrito(a) no CPF sob nº {{patient.cpf}}, portador(a) do RG nº {{patient.rg}}.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DO OBJETO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DA FREQUÊNCIA E DURAÇÃO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DO VALOR E FORMA DE PAGAMENTO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DA CONFIDENCIALIDADE","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DO CANCELAMENTO E FALTA","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td10$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();
-- Template 11: Contrato de Avaliação Psicológica
INSERT INTO public.catalog_document_templates (
  id, title, description, template_category, template_data, usage_count
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid,
  'Contrato de Prestação de Serviços de Avaliação Psicológica',
  'Template de contrato de prestação de serviços de avaliação psicológica',
  'contract',
  $td11${"version":"1.0","metadata":{"category":"contract","description":"Template gerado em 11/02/2026"},"content":{"root":{"type":"root","children":[{"type":"paragraph","children":[{"type":"text","text":"CONTRATO DE PRESTAÇÃO DE SERVIÇOS DE AVALIAÇÃO PSICOLÓGICA","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DAS PARTES","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"PSICÓLOGO(A): {{psychologist.fullName}}, inscrito(a) no CPF sob nº {{psychologist.cpf}}, com inscrição profissional no Conselho Regional de Psicologia {{psychologist.crpFull}}.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"AVALIADO(A): {{patient.fullName}}, inscrito(a) no CPF sob nº {{patient.cpf}}, portador(a) do RG nº {{patient.rg}}.","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DO OBJETO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DA NATUREZA DA AVALIAÇÃO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DOS PROCEDIMENTOS","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DO PRAZO E ENTREGA","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"DO VALOR E CONDIÇÕES DE PAGAMENTO","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{system.currentDateExtended}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""},{"type":"paragraph","children":[{"type":"text","text":"{{psychologist.fullName}} - {{psychologist.crpFull}}","format":0,"version":1}],"format":"","indent":0,"direction":"ltr","version":1,"textFormat":0,"textStyle":""}],"direction":"ltr","format":"","indent":0,"version":1}}}$td11$::jsonb,
  0
)
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  template_category = EXCLUDED.template_category,
  template_data = EXCLUDED.template_data,
  updated_at = NOW();

-- -----------------------------------------------------------------------------
-- 005 — Subscription plans
-- -----------------------------------------------------------------------------
-- ============================================================================
-- Seed: Subscription plans
-- Description: Catalog rows for Basic, Space, and Plus (coming soon)
-- Order: 005 (no dependencies)
-- ============================================================================

INSERT INTO public.subscription_plans (
  id,
  subscription_plan_id,
  plan_name,
  name,
  description,
  amount_cents,
  currency,
  interval,
  interval_count,
  stripe_price_id,
  stripe_product_id,
  features,
  is_active,
  metadata,
  created_at,
  updated_at
)
VALUES
  (
    'basic',
    'basic',
    'Basic',
    'fluri Basic',
    'O essencial para começar sua prática.',
    0,
    'brl',
    'month',
    1,
    NULL,
    NULL,
    '[
      "Divulgação no Marketplace",
      "Agrupador de Links para Bio",
      "Site Profissional",
      "Lembrete de consulta via WhatsApp",
      "Agenda e Prontuário Simplificados",
      "Pagamentos pela plataforma"
    ]'::jsonb,
    true,
    '{"max_patients": 5, "can_use_ai": false, "support_level": "basic"}'::jsonb,
    now(),
    now()
  ),
  (
    'space',
    'space',
    'Space',
    'fluri Space',
    'Organização e rotina no dia a dia clínico.',
    8990,
    'brl',
    'month',
    1,
    'price_1SXPQtC4qHVfQvUcy7itcdbK',
    NULL,
    '[
      "Tudo do plano Basic",
      "Destaque no Marketplace",
      "Taxas mínimas de transação",
      "Site Profissional Completo",
      "Agenda Inteligente",
      "Prontuário Completo",
      "Gestão Financeira"
    ]'::jsonb,
    true,
    '{"max_patients": null, "can_use_ai": true, "support_level": "priority"}'::jsonb,
    now(),
    now()
  ),
  (
    'plus',
    'plus',
    'Space+',
    'fluri Space+',
    'Para quem quer crescer com mais estrutura.',
    NULL,
    'brl',
    'month',
    1,
    NULL,
    NULL,
    '[
      "Tudo do plano Space",
      "Receita Saúde Automática (CPF)",
      "Geração de NFSe Automática (CNPJ)",
      "Suporte Prioritário",
      "Múltiplos profissionais",
      "API dedicada"
    ]'::jsonb,
    false,
    '{"max_patients": null, "can_use_ai": true, "support_level": "dedicated", "coming_soon": true}'::jsonb,
    now(),
    now()
  )
ON CONFLICT (id) DO UPDATE SET
  subscription_plan_id = EXCLUDED.subscription_plan_id,
  plan_name = EXCLUDED.plan_name,
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  amount_cents = EXCLUDED.amount_cents,
  currency = EXCLUDED.currency,
  interval = EXCLUDED.interval,
  interval_count = EXCLUDED.interval_count,
  stripe_price_id = EXCLUDED.stripe_price_id,
  stripe_product_id = EXCLUDED.stripe_product_id,
  features = EXCLUDED.features,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata,
  updated_at = now();
