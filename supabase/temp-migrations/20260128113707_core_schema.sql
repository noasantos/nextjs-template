-- TYPES
CREATE EXTENSION IF NOT EXISTS moddatetime;
DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;
DO $$ BEGIN CREATE TYPE public.app_role AS ENUM ('psychologist',
  'patient',
  'assistant',
  'admin'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.business_type AS ENUM ('PF', 'PJ'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.clinical_note_type AS ENUM ('session_note',
      'hypothesis',
      'treatment_plan',
      'risk_assessment',
      'test_result',
      'progress_note',
      'general_note',
      'case_conceptualization',
      'supervision_note',
      'personal_reflection',
      'personal_note'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.clinical_scope AS ENUM ('therapy',
      'assessment',
      'intervention',
      'psychoeducation',
      'report',
      'supervision'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.clinical_session_status AS ENUM ('scheduled',
      'completed',
      'cancelled',
      'no_show',
      'open'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.contact_method_type AS ENUM ('whatsapp',
      'sms',
      'email',
      'phone'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.delivery_mode AS ENUM ('in_person',
      'telehealth',
      'hybrid'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.financial_entry_status AS ENUM ('confirmed',
      'pending',
      'cancelled'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.interview_kind AS ENUM ('structured',
      'semi_structured',
      'unstructured'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.medical_item_kind AS ENUM ('mental_disorder',
      'chronic_disease',
      'physical_disability',
      'other',
      'medication_intake'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.modality AS ENUM ('individual',
      'couple',
      'family',
      'group'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.patient_status AS ENUM ('active',
      'inactive',
      'on_break',
      'discharged'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.payment_method_type AS ENUM ('fluripay',
      'card',
      'cash',
      'pix',
      'bank_transfer',
      'other'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.payment_status_type AS ENUM ('pending',
      'paid',
      'overdue',
      'refunded',
      'cancelled'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.population AS ENUM ('child',
      'adolescent',
      'adult',
      'older_adult'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.reschedule_initiator AS ENUM ('psychologist',
      'client'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.reschedule_request_status AS ENUM ('pending',
      'accepted',
      'rejected'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.risk_level_type AS ENUM ('low',
      'medium',
      'high',
      'critical'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.session_cancellation_policy_code AS ENUM ('flexible',
      'standard',
      'strict',
      'non_refundable'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.cancellation_policy_code AS ENUM ('flexible',
      'standard',
      'strict',
      'non_refundable'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.timeline_event_type AS ENUM ('patient_created',
       'patient_updated',
       'patient_archived',
       'patient_unarchived',
       'session_scheduled',
       'session_completed',
       'session_cancelled',
       'session_rescheduled',
       'session_no_show',
       'document_generated',
       'document_uploaded',
       'document_archived',
       'activity_assigned',
       'activity_completed',
       'activity_response_received',
       'activity_archived',
       'charge_created',
       'charge_cancelled',
       'payment_received',
       'payment_processed',
       'payment_overdue',
       'refund_processed',
       'note_added',
       'note_updated',
       'note_archived',
       'consent_signed',
       'invite_sent',
       'invite_reminder_sent',
       'account_linked',
       'condition_added',
       'condition_updated',
       'medication_added',
       'medication_updated',
       'emergency_contact_added',
       'emergency_contact_updated',
       'emergency_contact_removed',
       'label_assigned',
       'label_removed',
       'test_applied',
       'test_result_added',
       'test_archived',
       'guardian_added',
       'guardian_updated',
       'guardian_document_uploaded',
       'guardian_document_validated',
       'status_changed',
       'risk_assessment_updated',
       'relationship_started',
       'relationship_ended'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.invite_status_type AS ENUM ('pending',
      'accepted',
      'expired',
      'cancelled'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.onboarding_module AS ENUM ('professional_registration',
      'identity_verification',
      'practice_configuration'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.transaction_type AS ENUM ('INCOME', 'EXPENSE'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.clinical_note_type AS ENUM ('clinical_note',
  'progress_note',
  'hypothesis',
  'treatment_plan',
  'risk_assessment',
  'test_result'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.practice_modality AS ENUM ('in_person', 'online', 'hybrid'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.clinical_session_status_new AS ENUM ('scheduled',
  'open',
  'completed',
  'cancelled',
  'no_show'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- TABLES
CREATE TABLE IF NOT EXISTS public.roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name public.app_role UNIQUE NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  role public.app_role NOT NULL,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  assigned_by UUID,
  UNIQUE(user_id, role)
);
CREATE TABLE IF NOT EXISTS public.psychologists (
  id UUID PRIMARY KEY,
  username TEXT,
  professional_title TEXT,
  full_name TEXT,
  display_name TEXT,
  phone TEXT,
  business_type public.business_type,
  timezone TEXT,
  avatar_url TEXT,
  crp TEXT,
  crp_state TEXT,
  practice_modality public.practice_modality,
  onboarding_completed BOOLEAN DEFAULT false,
  subscription_status TEXT,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  first_name TEXT,
  last_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_profiles (
  id UUID PRIMARY KEY REFERENCES public.psychologists(id) ON DELETE CASCADE,
  full_name TEXT,
  username TEXT,
  professional_title TEXT,
  crp TEXT,
  crp_state TEXT,
  bio TEXT,
  neighborhood TEXT,
  specialties TEXT[],
  therapeutic_approaches TEXT[],
  session_duration INTEGER,
  session_price INTEGER,
  slug TEXT,
  avatar_path TEXT,
  background_path TEXT,
  social_links JSONB,
  linktree_theme TEXT,
  profile_sections JSONB,
  video_section JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.patients (
  id UUID PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  display_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.assistants (
  id UUID PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.admins (
  id UUID PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.webhook_events (
  event_id TEXT PRIMARY KEY,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  user_type TEXT,
  table_name TEXT,
  record_id TEXT,
  action TEXT,
  changed_fields JSONB,
  ip_address INET,
  user_agent TEXT,
  correlation_id UUID DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES public.patients(id) ON DELETE SET NULL,
  manual_full_name TEXT,
  synced_full_name TEXT,
  manual_display_name TEXT,
  synced_display_name TEXT,
  manual_email TEXT,
  manual_phone TEXT,
  manual_date_of_birth DATE,
  synced_date_of_birth DATE,
  preferred_contact_method public.contact_method_type,
  status TEXT DEFAULT 'active',
  risk_level TEXT,
  initial_complaint TEXT,
  clinical_hypothesis TEXT,
  therapeutic_goals JSONB,
  default_session_price INTEGER,
  relationship_start_date DATE,
  informed_consent_signed BOOLEAN DEFAULT false,
  informed_consent_date DATE,
  data_sharing_consent BOOLEAN DEFAULT false,
  data_sharing_consent_date DATE,
  invite_status public.invite_status_type,
  invite_sent_via public.contact_method_type,
  invited_at TIMESTAMPTZ,
  last_session_date DATE,
  total_sessions_count INTEGER DEFAULT 0,
  deleted_at TIMESTAMPTZ,
  recovery_deadline TIMESTAMPTZ,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.clinical_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_client_id UUID REFERENCES public.psychologist_clients(id) ON DELETE CASCADE,
  psychologist_service_id UUID,
  location_id UUID,
  start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  duration_minutes INTEGER,
  status TEXT DEFAULT 'scheduled',
  custom_price_cents INTEGER,
  snapshot_price INTEGER,
  snapshot_price_cents INTEGER,
  snapshot_service_name TEXT,
  notes TEXT,
  default_charge_id UUID,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_client_charges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_client_id UUID REFERENCES public.psychologist_clients(id) ON DELETE CASCADE,
  session_id UUID REFERENCES public.clinical_sessions(id) ON DELETE SET NULL,
  price_cents INTEGER DEFAULT 0,
  due_date DATE,
  paid_at TIMESTAMPTZ,
  payment_status TEXT DEFAULT 'pending',
  payment_method public.payment_method_type,
  description TEXT,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.financial_transaction_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID REFERENCES public.psychologists(id) ON DELETE CASCADE,
  type public.transaction_type NOT NULL,
  code TEXT,
  name TEXT NOT NULL DEFAULT 'Categoria',
  description TEXT,
  is_selectable BOOLEAN DEFAULT true,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.financial_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID REFERENCES public.psychologists(id) ON DELETE CASCADE,
  category_name TEXT NOT NULL,
  category_type TEXT NOT NULL,
  color TEXT,
  icon TEXT,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  is_default BOOLEAN DEFAULT false,
  display_order INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_financial_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  amount INTEGER NOT NULL DEFAULT 0,
  date_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status public.financial_entry_status,
  payment_method public.payment_method_type,
  description TEXT,
  category_id UUID,
  charge_id UUID REFERENCES public.psychologist_client_charges(id) ON DELETE SET NULL,
  session_id UUID REFERENCES public.clinical_sessions(id) ON DELETE SET NULL,
  parent_recurrence_id UUID,
  transaction_category_id UUID REFERENCES public.financial_transaction_categories(id) ON DELETE SET NULL,
  is_automatically_generated BOOLEAN DEFAULT false,
  weekly_period_start TIMESTAMPTZ,
  weekly_period_end TIMESTAMPTZ,
  charges_count INTEGER,
  consolidation_type TEXT,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.patient_emergency_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_client_id UUID NOT NULL REFERENCES public.psychologist_clients(id) ON DELETE CASCADE,
  contact_name TEXT NOT NULL,
  relationship TEXT,
  phone TEXT,
  email TEXT,
  is_primary BOOLEAN DEFAULT false,
  notes TEXT,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.patient_timeline_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_client_id UUID NOT NULL REFERENCES public.psychologist_clients(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_data JSONB,
  event_metadata JSONB,
  created_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.recurring_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  description TEXT,
  category_id UUID,
  transaction_category_id UUID REFERENCES public.financial_transaction_categories(id) ON DELETE SET NULL,
  recurrence_pattern TEXT,
  recurrence_interval INTEGER,
  recurrence_day_of_month INTEGER,
  start_date DATE,
  next_occurrence DATE,
  payment_method public.payment_method_type,
  auto_confirm BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  stripe_invoice_id TEXT,
  stripe_subscription_id TEXT,
  status TEXT,
  amount_paid INTEGER,
  currency TEXT,
  period_start DATE,
  period_end DATE,
  hosted_invoice_url TEXT,
  invoice_pdf TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  therapist_id UUID REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_id UUID REFERENCES public.psychologists(id) ON DELETE CASCADE,
  subscription_plan_id TEXT,
  stripe_subscription_id TEXT,
  stripe_price_id TEXT,
  status TEXT,
  trial_end TIMESTAMPTZ,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT false,
  has_active_subscription BOOLEAN DEFAULT false,
  metadata JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.linktree_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  title TEXT,
  url TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER,
  display_order INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE,
  notifications_email_reminders BOOLEAN DEFAULT true,
  notifications_whatsapp_reminders BOOLEAN DEFAULT true,
  notifications_billing_alerts BOOLEAN DEFAULT true,
  notifications_payment_receipts BOOLEAN DEFAULT true,
  notifications_security_alerts BOOLEAN DEFAULT true,
  notifications_marketing BOOLEAN DEFAULT false,
  preferences JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.user_preferences_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  old_values JSONB,
  new_values JSONB,
  action TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.session_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE,
  name TEXT NOT NULL DEFAULT 'Sessao',
  default_duration_minutes INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  service_id UUID,
  name TEXT,
  description TEXT,
  price INTEGER,
  duration_minutes INTEGER,
  is_active BOOLEAN DEFAULT true,
  is_public BOOLEAN DEFAULT false,
  sort_order INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_client_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_client_id UUID NOT NULL REFERENCES public.psychologist_clients(id) ON DELETE CASCADE,
  service_id UUID,
  price_cents INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  name TEXT,
  street TEXT,
  number TEXT,
  neighborhood TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_primary BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL,
  delivery_mode public.delivery_mode NOT NULL,
  effective_start DATE,
  effective_end DATE,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  available_for_first_appointment BOOLEAN DEFAULT true,
  location_id UUID REFERENCES public.psychologist_locations(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.availability_exceptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  exception_date DATE NOT NULL,
  is_available BOOLEAN DEFAULT false,
  start_time TIME,
  end_time TIME,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.session_reschedule_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES public.clinical_sessions(id) ON DELETE CASCADE,
  initiated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  responded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  requested_start_time TIMESTAMPTZ,
  requested_end_time TIMESTAMPTZ,
  reason TEXT,
  status public.reschedule_request_status DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_session_cancellation_policy (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  policy_code public.cancellation_policy_code,
  effective_from TIMESTAMPTZ DEFAULT NOW(),
  cancellation_window_hours INTEGER,
  penalty_percent INTEGER,
  notes TEXT,
  effective_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_onboarding_state (
  psychologist_id UUID PRIMARY KEY REFERENCES public.psychologists(id) ON DELETE CASCADE,
  current_step INTEGER DEFAULT 1,
  draft_data JSONB DEFAULT '{}'::jsonb,
  onboarding_completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.clinical_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_client_id UUID REFERENCES public.psychologist_clients(id) ON DELETE SET NULL,
  patient_id UUID REFERENCES public.psychologist_clients(id) ON DELETE SET NULL,
  session_id UUID REFERENCES public.clinical_sessions(id) ON DELETE SET NULL,
  note_type public.clinical_note_type,
  title TEXT,
  encoded_content TEXT,
  tags TEXT[],
  is_archived BOOLEAN DEFAULT false,
  content TEXT,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.document_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  template_category TEXT NOT NULL DEFAULT 'other',
  template_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.generated_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_client_id UUID REFERENCES public.psychologist_clients(id) ON DELETE SET NULL,
  title TEXT,
  content TEXT,
  created_by UUID,
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_patient_guardians (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE,
  name TEXT,
  relationship TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_patient_guardian_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  guardian_id UUID REFERENCES public.psychologist_patient_guardians(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES public.patients(id) ON DELETE CASCADE,
  file_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychologist_patient_medical_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  therapist_client_id UUID REFERENCES public.psychologist_clients(id) ON DELETE CASCADE,
  kind public.medical_item_kind,
  name TEXT,
  icd10_code TEXT,
  dosage TEXT,
  frequency TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  diagnosed_date DATE,
  item_kind public.medical_item_kind,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.patient_tests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_client_id UUID REFERENCES public.psychologist_clients(id) ON DELETE CASCADE,
  practice_id UUID,
  name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.patient_activity_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  psychologist_id UUID NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  psychologist_client_id UUID REFERENCES public.psychologist_clients(id) ON DELETE CASCADE,
  practice_id UUID,
  title TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.stripe_price_plans (
  id TEXT PRIMARY KEY,
  stripe_price_id TEXT,
  stripe_product_id TEXT,
  name TEXT,
  description TEXT,
  amount_cents INTEGER,
  currency TEXT DEFAULT 'brl',
  interval TEXT,
  interval_count INTEGER,
  is_active BOOLEAN DEFAULT true,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.clinical_activities_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  name TEXT,
  title TEXT,
  description TEXT,
  active BOOLEAN DEFAULT true,
  pdf_path TEXT,
  media_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychology_specialties_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  display_order INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychological_approaches_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  display_order INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS public.psychological_services_catalog (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  default_duration_minutes INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT true,
  display_order INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- OTHERS
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'idx_user_roles_user_id' AND table_schema = 'public') THEN
        CREATE INDEX idx_user_roles_user_id ON public.user_roles(user_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'idx_user_roles_role' AND table_schema = 'public') THEN
        CREATE INDEX idx_user_roles_role ON public.user_roles(role);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
INSERT INTO public.roles (name, description) VALUES
  ('psychologist', 'Psychologist - full access to main application'),
  ('patient', 'Patient - access to patient portal'),
  ('assistant', 'Assistant - access to assistant portal'),
  ('admin', 'Administrator - access to admin panel')
ON CONFLICT (name) DO NOTHING;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'column' AND table_schema = 'public') THEN
        comment on column public.psychologist_client_charges.price_cents is 'Charge price in cents (e.g., 15000 = R$150.00)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DROP FUNCTION IF EXISTS public.handle_new_session_charge() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_new_session_charge ()

RETURNS TRIGGER AS $$
DECLARE
    charge_id uuid;
    rows_updated integer;
BEGIN
    
    
    IF NEW.psychologist_client_id IS NOT NULL THEN
        INSERT INTO public.psychologist_client_charges (
            psychologist_id,
            psychologist_client_id,
            session_id,
            price_cents,
            due_date,
            payment_status,
            description,
            created_by,
            updated_by
        )
        VALUES (
            NEW.psychologist_id,
            NEW.psychologist_client_id,
            NEW.id,
            COALESCE(NEW.custom_price_cents, NEW.snapshot_price, 0),
            NEW.start_time::date,
            'pending',
            COALESCE(NEW.snapshot_service_name, 'Sessão de Terapia'),
            NEW.created_by::uuid,
            NEW.updated_by::uuid
        )
        RETURNING id INTO charge_id;
        
        
        
        UPDATE public.clinical_sessions
        SET default_charge_id = charge_id,
            updated_at = NOW()
        WHERE id = NEW.id;
        
        
        GET DIAGNOSTICS rows_updated = ROW_COUNT;
        
        
        IF rows_updated = 0 THEN
            RAISE WARNING 'Failed to update default_charge_id for session %', NEW.id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DROP FUNCTION IF EXISTS public.handle_session_update_charge() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_session_update_charge ()

RETURNS TRIGGER AS $$
BEGIN
    
    
    UPDATE public.psychologist_client_charges
    SET 
        price_cents = COALESCE(NEW.custom_price_cents, NEW.snapshot_price, 0),
        due_date = NEW.start_time::date,
        description = COALESCE(NEW.snapshot_service_name, description)
    WHERE 
        session_id = NEW.id 
        AND payment_status = 'pending';
        
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'clinical_sessions' AND table_schema = 'public') THEN
        DROP TRIGGER IF EXISTS on_session_created_charge ON public.clinical_sessions;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'clinical_sessions' AND table_schema = 'public') THEN
        CREATE TRIGGER on_session_created_charge
    AFTER INSERT ON public.clinical_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_session_charge();
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'clinical_sessions' AND table_schema = 'public') THEN
        DROP TRIGGER IF EXISTS on_session_updated_charge ON public.clinical_sessions;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'clinical_sessions' AND table_schema = 'public') THEN
        CREATE TRIGGER on_session_updated_charge
    AFTER UPDATE ON public.clinical_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_session_update_charge();
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'TABLE' AND table_schema = 'public') THEN
        COMMENT ON TABLE public.psychologist_financial_entries IS 'Financial transactions (income and expenses) for the psychologist. Focuses on financial health, not patient-specific context.';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS tagline text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS languages text[],
  ADD COLUMN IF NOT EXISTS practice_modality public.practice_modality;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.display_name IS 'Professional display name for public profile';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.tagline IS 'Professional tagline or short description';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.city IS 'City where psychologist practices';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.state IS 'State where psychologist practices';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.languages IS 'Languages spoken by psychologist';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.practice_modality IS 'Practice modality: in_person, online, or hybrid';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS academic_timeline jsonb,
  ADD COLUMN IF NOT EXISTS professional_timeline jsonb,
  ADD COLUMN IF NOT EXISTS registered_specialties text[];
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.academic_timeline IS 'Academic background timeline (jsonb)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.professional_timeline IS 'Professional experience timeline (jsonb)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.registered_specialties IS 'Registered professional specialties';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS background_url text,
  ADD COLUMN IF NOT EXISTS gallery_photos text[];
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.avatar_url IS 'Profile avatar URL';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.background_url IS 'Profile background/cover image URL';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.gallery_photos IS 'Array of gallery photo URLs';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS is_public boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS show_in_marketplace boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS profile_completed boolean DEFAULT false;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.is_public IS 'Whether profile is publicly visible';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.show_in_marketplace IS 'Whether to show in marketplace discovery';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.profile_completed IS 'Whether profile setup is completed';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_profiles_city_state 
  ON public.psychologist_profiles (city, state) 
  WHERE city IS NOT NULL AND state IS NOT NULL;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_profiles_practice_modality 
  ON public.psychologist_profiles (practice_modality) 
  WHERE practice_modality IS NOT NULL;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_profiles_public 
  ON public.psychologist_profiles (is_public, show_in_marketplace);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
UPDATE public.psychologist_profiles pp
SET 
  display_name = COALESCE(pp.display_name, p.display_name, p.full_name),
  avatar_url = COALESCE(pp.avatar_url, p.avatar_url),
  practice_modality = COALESCE(pp.practice_modality, p.practice_modality)
FROM public.psychologists p
WHERE pp.id = p.id
  AND (pp.display_name IS NULL OR pp.avatar_url IS NULL OR pp.practice_modality IS NULL);
UPDATE public.psychologist_profiles 
SET 
  languages = COALESCE(languages, ARRAY['Português']),
  tagline = COALESCE(tagline, 'Psicólogo Clínico'),
  is_public = COALESCE(is_public, true)
WHERE languages IS NULL OR tagline IS NULL OR is_public IS NULL;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_select_public" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_select_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_update_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_select_public"
  ON public.psychologist_profiles
  FOR SELECT
  TO anon
  USING (
    is_public = true AND 
    display_name IS NOT NULL
  );
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_select_own"
  ON public.psychologist_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_update_own"
  ON public.psychologist_profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DROP FUNCTION IF EXISTS check_profile_completion(uuid) CASCADE;
CREATE OR REPLACE FUNCTION check_profile_completion (p_psychologist_id uuid)

RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  completion_score integer := 0;
  max_score integer := 8;
BEGIN
  
  SELECT 
    CASE WHEN display_name IS NOT NULL AND length(trim(display_name)) > 0 THEN 1 ELSE 0 END +
    CASE WHEN bio IS NOT NULL AND length(trim(bio)) > 50 THEN 1 ELSE 0 END +
    CASE WHEN avatar_url IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN array_length(specialties, 1) > 0 THEN 1 ELSE 0 END +
    CASE WHEN array_length(therapeutic_approaches, 1) > 0 THEN 1 ELSE 0 END +
    CASE WHEN practice_modality IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN city IS NOT NULL AND state IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN languages IS NOT NULL AND array_length(languages, 1) > 0 THEN 1 ELSE 0 END
  INTO completion_score
  FROM psychologist_profiles
  WHERE id = p_psychologist_id;
  
  
  UPDATE psychologist_profiles
  SET profile_completed = (completion_score >= 6) 
  WHERE id = p_psychologist_id;
  
  RETURN completion_score >= 6;
END;
$$;
GRANT EXECUTE ON FUNCTION check_profile_completion(uuid) TO authenticated, service_role;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS tagline text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS languages text[],
  ADD COLUMN IF NOT EXISTS practice_modality public.practice_modality,
  ADD COLUMN IF NOT EXISTS academic_timeline jsonb,
  ADD COLUMN IF NOT EXISTS professional_timeline jsonb,
  ADD COLUMN IF NOT EXISTS registered_specialties text[],
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS background_url text,
  ADD COLUMN IF NOT EXISTS gallery_photos text[],
  ADD COLUMN IF NOT EXISTS is_public boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS show_in_marketplace boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS profile_completed boolean DEFAULT false;
UPDATE public.psychologist_profiles pp
SET 
  display_name = COALESCE(pp.display_name, p.display_name, p.full_name),
  avatar_url = COALESCE(pp.avatar_url, p.avatar_url),
  practice_modality = COALESCE(pp.practice_modality, p.practice_modality)
FROM public.psychologists p
WHERE pp.id = p.id
  AND (pp.display_name IS NULL OR pp.avatar_url IS NULL OR pp.practice_modality IS NULL);
UPDATE public.psychologist_profiles 
SET 
  languages = COALESCE(languages, ARRAY['Português']),
  tagline = COALESCE(tagline, 'Psicólogo Clínico'),
  is_public = COALESCE(is_public, true)
WHERE languages IS NULL OR tagline IS NULL OR is_public IS NULL;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS display_name text,
  ADD COLUMN IF NOT EXISTS tagline text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS languages text[],
  ADD COLUMN IF NOT EXISTS practice_modality public.practice_modality;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.display_name IS 'Professional display name for public profile';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.tagline IS 'Professional tagline or short description';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.city IS 'City where psychologist practices';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.state IS 'State where psychologist practices';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.languages IS 'Languages spoken by psychologist';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.practice_modality IS 'Practice modality: in_person, online, or hybrid';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS academic_timeline jsonb,
  ADD COLUMN IF NOT EXISTS professional_timeline jsonb,
  ADD COLUMN IF NOT EXISTS registered_specialties text[];
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.academic_timeline IS 'Academic background timeline (jsonb)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.professional_timeline IS 'Professional experience timeline (jsonb)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.registered_specialties IS 'Registered professional specialties';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS background_url text,
  ADD COLUMN IF NOT EXISTS gallery_photos text[];
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.avatar_url IS 'Profile avatar URL';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.background_url IS 'Profile background/cover image URL';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.gallery_photos IS 'Array of gallery photo URLs';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS is_public boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS show_in_marketplace boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS profile_completed boolean DEFAULT false;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.is_public IS 'Whether profile is publicly visible';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.show_in_marketplace IS 'Whether to show in marketplace discovery';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.profile_completed IS 'Whether profile setup is completed';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_profiles_city_state 
  ON public.psychologist_profiles (city, state) 
  WHERE city IS NOT NULL AND state IS NOT NULL;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_profiles_practice_modality 
  ON public.psychologist_profiles (practice_modality) 
  WHERE practice_modality IS NOT NULL;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_profiles_public 
  ON public.psychologist_profiles (is_public, show_in_marketplace);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
UPDATE public.psychologist_profiles pp
SET 
  display_name = COALESCE(pp.display_name, p.display_name, p.full_name),
  avatar_url = COALESCE(pp.avatar_url, p.avatar_url),
  practice_modality = COALESCE(pp.practice_modality, p.practice_modality)
FROM public.psychologists p
WHERE pp.id = p.id
  AND (pp.display_name IS NULL OR pp.avatar_url IS NULL OR pp.practice_modality IS NULL);
UPDATE public.psychologist_profiles 
SET 
  languages = COALESCE(languages, ARRAY['Português']),
  tagline = COALESCE(tagline, 'Psicólogo Clínico'),
  is_public = COALESCE(is_public, true)
WHERE languages IS NULL OR tagline IS NULL OR is_public IS NULL;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_select_public" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_select_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_update_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_select_public"
  ON public.psychologist_profiles
  FOR SELECT
  TO anon
  USING (
    is_public = true AND 
    display_name IS NOT NULL
  );
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_select_own"
  ON public.psychologist_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_update_own"
  ON public.psychologist_profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DROP FUNCTION IF EXISTS check_profile_completion(uuid) CASCADE;
CREATE OR REPLACE FUNCTION check_profile_completion (p_psychologist_id uuid)

RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  completion_score integer := 0;
  max_score integer := 8;
BEGIN
  
  SELECT 
    CASE WHEN display_name IS NOT NULL AND length(trim(display_name)) > 0 THEN 1 ELSE 0 END +
    CASE WHEN bio IS NOT NULL AND length(trim(bio)) > 50 THEN 1 ELSE 0 END +
    CASE WHEN avatar_url IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN array_length(specialties, 1) > 0 THEN 1 ELSE 0 END +
    CASE WHEN array_length(therapeutic_approaches, 1) > 0 THEN 1 ELSE 0 END +
    CASE WHEN practice_modality IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN city IS NOT NULL AND state IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN languages IS NOT NULL AND array_length(languages, 1) > 0 THEN 1 ELSE 0 END
  INTO completion_score
  FROM psychologist_profiles
  WHERE id = p_psychologist_id;
  
  
  UPDATE psychologist_profiles
  SET profile_completed = (completion_score >= 6) 
  WHERE id = p_psychologist_id;
  
  RETURN completion_score >= 6;
END;
$$;
GRANT EXECUTE ON FUNCTION check_profile_completion(uuid) TO authenticated, service_role;
ALTER TABLE public.psychologist_profiles
  ADD COLUMN IF NOT EXISTS profile_sections jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS video_section jsonb;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.profile_sections IS 'Ordered profile sections with active state';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychologist_profiles.video_section IS 'Video section configuration (url, title, description, thumbnail)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
UPDATE public.psychologist_profiles
SET profile_sections = COALESCE(profile_sections, '[]'::jsonb)
WHERE profile_sections IS NULL;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_psychologist_invoices_psychologist_id on public.psychologist_invoices(psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_psychologist_services_service_id on public.psychologist_services(service_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_psychologist_session_cancellation_policy_policy_code on public.psychologist_session_cancellation_policy(policy_code);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_recurring_transactions_category_id on public.recurring_transactions(category_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_recurring_transactions_transaction_category_id on public.recurring_transactions(transaction_category_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_session_reschedule_logs_created_by on public.session_reschedule_logs(created_by);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_session_reschedule_requests_initiated_by on public.session_reschedule_requests(initiated_by);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_session_reschedule_requests_responded_by on public.session_reschedule_requests(responded_by);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_sync_conflict_resolutions_conflict_id on public.sync_conflict_resolutions(conflict_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_sync_conflict_resolutions_psychologist_id on public.sync_conflict_resolutions(psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_sync_queue_psychologist_id on public.sync_queue(psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_user_preferences_audit_log_user_id on public.user_preferences_audit_log(user_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'if' AND table_schema = 'public') THEN
        create index if not exists idx_user_roles_assigned_by on public.user_roles(assigned_by);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_roles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "User roles are viewable by own user" ON public.user_roles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_roles' AND table_schema = 'public') THEN
        CREATE POLICY "User roles are viewable by own user"
  ON public.user_roles
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = user_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can update their own record" ON public.psychologists;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can read their own record" ON public.psychologists;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can insert their own record" ON public.psychologists;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        CREATE POLICY "Psychologists can update their own record"
  ON public.psychologists
  FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        CREATE POLICY "Psychologists can read their own record"
  ON public.psychologists
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        CREATE POLICY "Psychologists can insert their own record"
  ON public.psychologists
  FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_select_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_update_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_insert_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_select_own"
  ON public.psychologist_profiles
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_insert_own"
  ON public.psychologist_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_update_own"
  ON public.psychologist_profiles
  FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_services_select_own" ON public.psychologist_services;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_services_insert_own" ON public.psychologist_services;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_services_update_own" ON public.psychologist_services;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_services_delete_own" ON public.psychologist_services;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_services_select_own"
  ON public.psychologist_services
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_services_insert_own"
  ON public.psychologist_services
  FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_services_update_own"
  ON public.psychologist_services
  FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = psychologist_id)
  WITH CHECK ((select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_services_delete_own"
  ON public.psychologist_services
  FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologists_select_public_by_username" ON public.psychologists;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologists_select_admin" ON public.psychologists;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        CREATE POLICY "psychologists_select_public"
  ON public.psychologists
  FOR SELECT
  TO public
  USING (
    public.is_admin()
    OR (select auth.uid()) = id
    OR (
      username is not null
      AND exists (
        select 1 from public.psychologist_profiles pp
        where pp.id = psychologists.id and pp.is_public = true
      )
    )
  );
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_select_public" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_select_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_profiles_select_public_or_own"
  ON public.psychologist_profiles
  FOR SELECT
  TO public
  USING (
    (is_public = true AND display_name IS NOT NULL)
    OR (select auth.uid()) = id
  );
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_services_select_public" ON public.psychologist_services;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_services_select_own" ON public.psychologist_services;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_services_select_public_or_own"
  ON public.psychologist_services
  FOR SELECT
  TO public
  USING (
    (select auth.uid()) = psychologist_id
    OR (
      is_active = true
      AND exists (
        select 1 from public.psychologist_profiles pp
        where pp.id = psychologist_services.psychologist_id and pp.is_public = true
      )
    )
  );
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'linktree_links' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "linktree_links_select_public" ON public.linktree_links;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'linktree_links' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "linktree_links_select_own" ON public.linktree_links;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'linktree_links' AND table_schema = 'public') THEN
        CREATE POLICY "linktree_links_select_public_or_own"
  ON public.linktree_links
  FOR SELECT
  TO public
  USING (
    (select auth.uid()) = psychologist_id
    OR (
      is_active = true
      AND exists (
        select 1 from public.psychologist_profiles pp
        where pp.id = linktree_links.psychologist_id and pp.is_public = true
      )
    )
  );
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_roles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "user_roles_select_admin" ON public.user_roles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_roles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "user_roles_select_psychologist" ON public.user_roles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_roles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "User roles are viewable by own user" ON public.user_roles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_roles' AND table_schema = 'public') THEN
        CREATE POLICY "user_roles_select" ON public.user_roles
  FOR SELECT TO public
  USING (public.is_admin() OR (select auth.uid()) = user_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologists' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can read their own record" ON public.psychologists;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_profiles' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_profiles_select_own" ON public.psychologist_profiles;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_services' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_services_select_own" ON public.psychologist_services;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_invoices' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_invoices_select_own" ON public.psychologist_invoices;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_invoices' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_invoices_select_service_role" ON public.psychologist_invoices;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_invoices' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_invoices_select"
  ON public.psychologist_invoices
  FOR SELECT
  TO public
  USING (public.is_admin() OR (select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'session_reschedule_requests' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "reschedule_requests_select_psychologist" ON public.session_reschedule_requests;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'session_reschedule_requests' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "reschedule_requests_select_patient" ON public.session_reschedule_requests;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'session_reschedule_requests' AND table_schema = 'public') THEN
        CREATE POLICY "reschedule_requests_select"
  ON public.session_reschedule_requests
  FOR SELECT
  TO authenticated
  USING (
    exists (
      select 1 from public.clinical_sessions cs
      where cs.id = session_id
        and cs.psychologist_id = (select auth.uid())
    )
    OR exists (
      select 1 from public.clinical_sessions cs
      join public.psychologist_clients pc on pc.id = cs.psychologist_client_id
      where cs.id = session_id
        and pc.patient_id = (select auth.uid())
    )
  );
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'availability_settings' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can view own settings" ON public.availability_settings;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'availability_settings' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage own settings" ON public.availability_settings;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'availability_settings' AND table_schema = 'public') THEN
        CREATE POLICY "availability_settings_select_own"
  ON public.availability_settings
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'lunch_break_overrides' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can view own lunch overrides" ON public.lunch_break_overrides;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'lunch_break_overrides' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage own lunch overrides" ON public.lunch_break_overrides;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'lunch_break_overrides' AND table_schema = 'public') THEN
        CREATE POLICY "lunch_break_overrides_select_own"
  ON public.lunch_break_overrides
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_availability' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can view own availability" ON public.psychologist_availability;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_availability' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can manage own availability" ON public.psychologist_availability;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_availability' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_availability_select_own"
  ON public.psychologist_availability
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DROP INDEX IF EXISTS idx_psychologist_subscriptions_stripe_customer_id;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_invoices' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "psychologist_invoices_select" ON public.psychologist_invoices;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_invoices' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Psychologists can view their own invoices" ON public.psychologist_invoices;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_invoices' AND table_schema = 'public') THEN
        DROP POLICY IF EXISTS "Service role can manage invoices" ON public.psychologist_invoices;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_invoices' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_invoices_select"
  ON public.psychologist_invoices
  FOR SELECT
  TO public
  USING (public.is_admin() OR (select auth.uid()) = psychologist_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychologist_invoices' AND table_schema = 'public') THEN
        CREATE POLICY "psychologist_invoices_service_role"
  ON public.psychologist_invoices
  FOR ALL
  TO public
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
BEGIN;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'TABLE' AND table_schema = 'public') THEN
        COMMENT ON TABLE public.psychology_specialties_catalog IS 'Master catalog of psychological specialties recognized by CFP (Conselho Federal de Psicologia)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychology_specialties_catalog.code IS 'Unique specialty code';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychology_specialties_catalog.name IS 'Specialty name in Portuguese';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychology_specialties_catalog.description IS 'Description of the specialty';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychology_specialties_catalog.is_active IS 'Whether this specialty is currently available for selection';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychology_specialties_catalog.display_order IS 'Order for display in UI';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychology_specialties_catalog' AND table_schema = 'public') THEN
        ALTER TABLE public.psychology_specialties_catalog ENABLE ROW LEVEL SECURITY;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychology_specialties_catalog' AND table_schema = 'public') THEN
        CREATE POLICY "psychology_specialties_catalog_select_authenticated"
  ON public.psychology_specialties_catalog
  FOR SELECT
  TO authenticated
  USING (is_active = true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychology_specialties_catalog' AND table_schema = 'public') THEN
        CREATE POLICY "psychology_specialties_catalog_select_anon"
  ON public.psychology_specialties_catalog
  FOR SELECT
  TO anon
  USING (is_active = true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychology_specialties_catalog_code
  ON public.psychology_specialties_catalog(code);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychology_specialties_catalog_active
  ON public.psychology_specialties_catalog(is_active)
  WHERE is_active = true;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
INSERT INTO public.psychology_specialties_catalog (code, name, description, is_active, display_order, created_at, updated_at)
VALUES
  ('CLINICAL', 'Psicologia Clínica', 'Atuação em diagnóstico, avaliação e intervenção clínica com indivíduos, grupos e famílias.', true, 1, NOW(), NOW()),
  ('EDUCATIONAL', 'Psicologia Escolar e Educacional', 'Trabalho em contexto escolar com foco em desenvolvimento, aprendizagem e relacionamento.', true, 2, NOW(), NOW()),
  ('ORGANIZATIONAL', 'Psicologia Organizacional e do Trabalho', 'Consultoria, seleção, desenvolvimento de pessoas e psicologia organizacional em empresas.', true, 3, NOW(), NOW()),
  ('TRAFFIC', 'Psicologia do Trânsito', 'Avaliação psicológica de motoristas, estudos comportamentais de segurança no trânsito.', true, 4, NOW(), NOW()),
  ('LEGAL', 'Psicologia Jurídica', 'Atuação no sistema judiciário, avaliações forenses, mediação e consultoria jurídica.', true, 5, NOW(), NOW()),
  ('SPORTS', 'Psicologia do Esporte', 'Atendimento a atletas, desenvolvimento de potencial, melhora de performance.', true, 6, NOW(), NOW()),
  ('HOSPITAL', 'Psicologia Hospitalar', 'Atendimento em ambientes hospitalares, preparação para procedimentos e apoio emocional.', true, 7, NOW(), NOW()),
  ('PSYCHOPEDAGOGY', 'Psicopedagogia', 'Diagnóstico e intervenção em dificuldades de aprendizagem e desenvolvimento cognitivo.', true, 8, NOW(), NOW()),
  ('PSYCHOMOTRICITY', 'Psicomotricidade', 'Trabalho com desenvolvimento motor, coordenação e relação corpo-mente.', true, 9, NOW(), NOW()),
  ('SOCIAL', 'Psicologia Social', 'Análise de processos grupais, comunitários e sociais, atuação em políticas públicas.', true, 10, NOW(), NOW()),
  ('NEUROPSYCHOLOGY', 'Neuropsicologia', 'Avaliação e reabilitação cognitiva em transtornos neurológicos e do neurodesenvolvimento.', true, 11, NOW(), NOW()),
  ('HEALTH', 'Psicologia da Saúde', 'Promoção de saúde, prevenção de doenças e apoio psicológico em contextos de saúde.', true, 12, NOW(), NOW()),
  ('ASSESSMENT', 'Avaliação Psicológica', 'Aplicação e interpretação de testes psicométricos e psicodiagnóstico.', true, 13, NOW(), NOW()),
  ('PUBLIC_POLICY', 'Psicologia em Políticas Públicas', 'Atuação em projetos e políticas públicas nas esferas federal, estadual e municipal.', true, 14, NOW(), NOW()),
  ('SEXOLOGY', 'Sexologia', 'Atendimento em questões de sexualidade, disfunções sexuais e educação sexual.', true, 15, NOW(), NOW())
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  display_order = EXCLUDED.display_order,
  updated_at = NOW();
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'TABLE' AND table_schema = 'public') THEN
        COMMENT ON TABLE public.psychological_approaches_catalog IS 'Master catalog of psychological therapeutic approaches and methodologies';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_approaches_catalog.code IS 'Unique approach code';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_approaches_catalog.name IS 'Approach name in Portuguese';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_approaches_catalog.description IS 'Description of the therapeutic approach';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_approaches_catalog.is_active IS 'Whether this approach is currently available for selection';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_approaches_catalog.display_order IS 'Order for display in UI';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychological_approaches_catalog' AND table_schema = 'public') THEN
        ALTER TABLE public.psychological_approaches_catalog ENABLE ROW LEVEL SECURITY;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychological_approaches_catalog' AND table_schema = 'public') THEN
        CREATE POLICY "psychological_approaches_catalog_select_authenticated"
  ON public.psychological_approaches_catalog
  FOR SELECT
  TO authenticated
  USING (is_active = true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychological_approaches_catalog' AND table_schema = 'public') THEN
        CREATE POLICY "psychological_approaches_catalog_select_anon"
  ON public.psychological_approaches_catalog
  FOR SELECT
  TO anon
  USING (is_active = true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychological_approaches_catalog_code
  ON public.psychological_approaches_catalog(code);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychological_approaches_catalog_active
  ON public.psychological_approaches_catalog(is_active)
  WHERE is_active = true;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
INSERT INTO public.psychological_approaches_catalog (code, name, description, is_active, display_order, created_at, updated_at)
VALUES
  ('CBT', 'Terapia Cognitivo-Comportamental (TCC)', 'Abordagem focada na modificação de padrões de pensamento e comportamento', true, 1, NOW(), NOW()),
  ('PSYCHOANALYSIS', 'Psicanálise', 'Abordagem profunda centrada no inconsciente e dinâmica intrapsíquica', true, 2, NOW(), NOW()),
  ('HUMANISTIC', 'Humanista', 'Abordagem centrada na pessoa, no crescimento pessoal e na realização potencial', true, 3, NOW(), NOW()),
  ('PSYCHODYNAMIC', 'Psicodinâmica', 'Abordagem que integra conceitos psicanalíticos com uma técnica mais breve', true, 4, NOW(), NOW()),
  ('BEHAVIORAL', 'Comportamental', 'Abordagem focada no comportamento observável e sua modificação', true, 5, NOW(), NOW()),
  ('SYSTEMIC', 'Sistêmica/Familiar', 'Abordagem que considera a família e sistemas como um todo', true, 6, NOW(), NOW()),
  ('EXISTENTIAL', 'Existencial', 'Abordagem focada na liberdade, responsabilidade e significação da existência', true, 7, NOW(), NOW()),
  ('GESTALT', 'Gestalt', 'Abordagem que enfatiza a autorregulação do organismo e o aqui-agora', true, 8, NOW(), NOW()),
  ('ACT', 'Terapia de Aceitação e Compromisso (ACT)', 'Abordagem contemporânea que promove aceitação e vivência de acordo com valores', true, 9, NOW(), NOW()),
  ('EMDR', 'EMDR (Dessensibilização e Reprocessamento com Movimento dos Olhos)', 'Abordagem especializada em trauma e processamento de memórias', true, 10, NOW(), NOW()),
  ('DBT', 'Terapia Comportamental Dialética (DBT)', 'Abordagem especializada em transtornos emocionais e comportamentos autodestrutivos', true, 11, NOW(), NOW()),
  ('POSITIVE', 'Psicologia Positiva', 'Abordagem focada em forças, virtudes e bem-estar psicológico', true, 12, NOW(), NOW())
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  display_order = EXCLUDED.display_order,
  updated_at = NOW();
COMMIT;
BEGIN;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'TABLE' AND table_schema = 'public') THEN
        COMMENT ON TABLE public.psychological_services_catalog IS 'Master catalog of psychological service types available to psychologists';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_services_catalog.code IS 'Unique service code (e.g., INDIVIDUAL, GROUP)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_services_catalog.name IS 'Display name of the service (Portuguese)';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_services_catalog.description IS 'Description of the service';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_services_catalog.default_duration_minutes IS 'Default session duration in minutes';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'COLUMN' AND table_schema = 'public') THEN
        COMMENT ON COLUMN public.psychological_services_catalog.display_order IS 'Order for display in UI';
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychological_services_catalog' AND table_schema = 'public') THEN
        ALTER TABLE public.psychological_services_catalog ENABLE ROW LEVEL SECURITY;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychological_services_catalog' AND table_schema = 'public') THEN
        CREATE POLICY "psychological_services_catalog_select_authenticated"
  ON public.psychological_services_catalog
  FOR SELECT
  TO authenticated
  USING (is_active = true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'psychological_services_catalog' AND table_schema = 'public') THEN
        CREATE POLICY "psychological_services_catalog_select_anon"
  ON public.psychological_services_catalog
  FOR SELECT
  TO anon
  USING (is_active = true);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychological_services_catalog_code
  ON public.psychological_services_catalog(code);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'IF' AND table_schema = 'public') THEN
        CREATE INDEX IF NOT EXISTS idx_psychological_services_catalog_active
  ON public.psychological_services_catalog(is_active)
  WHERE is_active = true;
    END IF;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
INSERT INTO public.psychological_services_catalog (
  id,
  code,
  name,
  description,
  default_duration_minutes,
  is_active,
  display_order,
  created_at,
  updated_at
) VALUES
  
  (
    'a1b2c3d4-e5f6-7890-abcd-ef1234567890'::uuid,
    'INDIVIDUAL',
    'Psicoterapia Individual',
    'Sessão individual com psicólogo para atendimento clínico, psicoterapia e orientação psicológica.',
    50,
    true,
    1,
    NOW(),
    NOW()
  ),
  
  (
    'b2c3d4e5-f6a7-8901-bcde-f12345678901'::uuid,
    'GROUP',
    'Psicoterapia em Grupo',
    'Sessão de psicoterapia com múltiplos pacientes, desenvolvimento de habilidades sociais e suporte em grupo.',
    60,
    true,
    2,
    NOW(),
    NOW()
  ),
  
  (
    'c3d4e5f6-a7b8-9012-cdef-123456789012'::uuid,
    'COUPLES_FAMILY',
    'Terapia de Casal/Família',
    'Atendimento especializado para casais, famílias e relacionamentos interpessoais.',
    60,
    true,
    3,
    NOW(),
    NOW()
  ),
  
  (
    'd4e5f6a7-b8c9-0123-def1-234567890123'::uuid,
    'CHILD',
    'Psicoterapia Infantil',
    'Atendimento psicológico especializado para crianças, com técnicas lúdicas e apropriadas para a idade.',
    50,
    true,
    4,
    NOW(),
    NOW()
  ),
  
  (
    'e5f6a7b8-c9d0-1234-ef12-345678901234'::uuid,
    'ADOLESCENT',
    'Psicoterapia Adolescente',
    'Atendimento especializado para adolescentes, abordando desafios específicos dessa fase.',
    50,
    true,
    5,
    NOW(),
    NOW()
  ),
  
  (
    'f6a7b8c9-d0e1-2345-f123-456789012345'::uuid,
    'ASSESSMENT',
    'Avaliação Psicológica',
    'Avaliação e diagnóstico psicológico, testes e psicodiagnóstico.',
    90,
    true,
    6,
    NOW(),
    NOW()
  ),
  
  (
    'a7b8c9d0-e1f2-3456-0123-567890123456'::uuid,
    'PSYCHIATRIC',
    'Consulta Psiquiátrica',
    'Consulta com psiquiatra para avaliação de medicamentos e condições psiquiátricas.',
    50,
    true,
    7,
    NOW(),
    NOW()
  ),
  
  (
    'b8c9d0e1-f2a3-4567-1234-678901234567'::uuid,
    'CAREER',
    'Orientação Profissional',
    'Atendimento especializado em orientação vocacional e desenvolvimento de carreira.',
    50,
    true,
    8,
    NOW(),
    NOW()
  ),
  
  (
    'c9d0e1f2-a3b4-5678-2345-789012345678'::uuid,
    'CRISIS',
    'Intervenção em Crise',
    'Atendimento de emergência para situações de crise psicológica e suporte imediato.',
    30,
    true,
    9,
    NOW(),
    NOW()
  ),
  
  (
    'd0e1f2a3-b4c5-6789-3456-890123456789'::uuid,
    'COACHING',
    'Coaching Psicológico',
    'Sessão de coaching para desenvolvimento pessoal, produtividade e bem-estar.',
    50,
    true,
    10,
    NOW(),
    NOW()
  ),
  
  (
    'e1f2a3b4-c5d6-7890-4567-901234567890'::uuid,
    'SUPERVISION',
    'Supervisão Profissional',
    'Supervisão clínica para psicólogos, assistentes sociais e outros profissionais.',
    50,
    true,
    11,
    NOW(),
    NOW()
  ),
  
  (
    'f2a3b4c5-d6e7-8901-5678-012345678901'::uuid,
    'OTHER',
    'Outro Serviço',
    'Outro tipo de serviço psicológico não listado acima.',
    50,
    true,
    12,
    NOW(),
    NOW()
  )
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  default_duration_minutes = EXCLUDED.default_duration_minutes,
  is_active = EXCLUDED.is_active,
  display_order = EXCLUDED.display_order,
  updated_at = NOW();
COMMIT;
