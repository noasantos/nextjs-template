-- Migration: add_table_descriptions_and_refinements
-- Target Tables: account_deletion_requests, assistant_invites, psychologist_assistants, admins, subscription_plans, psychologist_subscriptions, audit_logs, psychologist_weekly_schedules, busy_slots, reference_values, catalog_clinical_activities, catalog_cancellation_policies, psychologist_session_cancellation_policy, psychologist_notes, catalog_document_templates, catalog_interview_templates, generated_documents, psychologist_clinical_sessions, public_profiles, public_linktree_links, public_locations, public_client_checkout_intents, psychologist_patients, psychologist_patient_activities, psychologist_patient_assessments, psychologist_patient_emergency_contacts, psychologist_financial_entries, psychologist_preferences

-------------------------------------------------------------------------------
-- 1. ACCOUNT DELETION REQUESTS
-------------------------------------------------------------------------------

-- Create ENUM for deletion status if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'account_deletion_status') THEN
        CREATE TYPE public.account_deletion_status AS ENUM (
            'requested', 
            'approved', 
            'processing', 
            'completed', 
            'failed', 
            'cancelled'
        );
    END IF;
END $$;
-- Add cancelled_at column
ALTER TABLE public.account_deletion_requests 
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;
-- Convert status column to use the new ENUM
-- Step A: Drop default to allow type change
ALTER TABLE public.account_deletion_requests ALTER COLUMN status DROP DEFAULT;
-- Step B: Convert type (using explicit cast to text then to enum)
-- Temporary column approach to avoid operator issues during conversion
ALTER TABLE public.account_deletion_requests ADD COLUMN status_new public.account_deletion_status;
UPDATE public.account_deletion_requests SET status_new = status::text::public.account_deletion_status;
ALTER TABLE public.account_deletion_requests DROP COLUMN status;
ALTER TABLE public.account_deletion_requests RENAME COLUMN status_new TO status;
-- Step C: Set new default with correct type
ALTER TABLE public.account_deletion_requests ALTER COLUMN status SET DEFAULT 'requested'::public.account_deletion_status;
ALTER TABLE public.account_deletion_requests ALTER COLUMN status SET NOT NULL;
-- Table and Column Descriptions
COMMENT ON TABLE public.account_deletion_requests IS 'Stores user requests for account deletion, tracking the lifecycle from initial request through approval, processing, and final completion or failure. Includes data retention periods and reasoning for deletion.';
COMMENT ON COLUMN public.account_deletion_requests.id IS 'Unique identifier for the deletion request.';
COMMENT ON COLUMN public.account_deletion_requests.user_id IS 'The ID of the user whose account is being deleted.';
COMMENT ON COLUMN public.account_deletion_requests.requested_by IS 'The ID of the user who initiated the request (can be the user themselves or an admin).';
COMMENT ON COLUMN public.account_deletion_requests.reason IS 'Optional reason provided by the user for deleting their account.';
COMMENT ON COLUMN public.account_deletion_requests.status IS 'Current state of the request using a controlled enum (requested, approved, processing, completed, failed, cancelled).';
COMMENT ON COLUMN public.account_deletion_requests.requested_at IS 'Timestamp when the deletion was first requested.';
COMMENT ON COLUMN public.account_deletion_requests.approved_at IS 'Timestamp when the request was approved for processing.';
COMMENT ON COLUMN public.account_deletion_requests.processing_started_at IS 'Timestamp when the background deletion process actually started.';
COMMENT ON COLUMN public.account_deletion_requests.processed_at IS 'Timestamp when the deletion process was successfully completed.';
COMMENT ON COLUMN public.account_deletion_requests.failed_at IS 'Timestamp when the deletion process encountered a terminal error.';
COMMENT ON COLUMN public.account_deletion_requests.failure_reason IS 'Detailed error message if the deletion process failed.';
COMMENT ON COLUMN public.account_deletion_requests.cancelled_at IS 'Timestamp when the deletion request was cancelled by the user or an admin.';
COMMENT ON COLUMN public.account_deletion_requests.retention_until IS 'Timestamp until which the data must be kept before permanent deletion, for legal or compliance reasons.';
COMMENT ON COLUMN public.account_deletion_requests.correlation_id IS 'Unique ID to correlate this request across distributed systems and logs.';
COMMENT ON COLUMN public.account_deletion_requests.metadata IS 'Flexible JSON storage for additional request context (e.g., IP address, source, etc.).';
-------------------------------------------------------------------------------
-- 2. ASSISTANT INVITES
-------------------------------------------------------------------------------

-- Remove redundant inviter_user_id (Psychologist is the inviter)
ALTER TABLE public.assistant_invites 
DROP COLUMN IF EXISTS inviter_user_id;
-- Make email optional to support Phone/WhatsApp invites
ALTER TABLE public.assistant_invites 
ALTER COLUMN invited_email DROP NOT NULL;
-- Add invited_phone and metadata
ALTER TABLE public.assistant_invites 
ADD COLUMN IF NOT EXISTS invited_phone TEXT,
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
-- Ensure at least email or phone is provided
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'assistant_invites_contact_check') THEN
        ALTER TABLE public.assistant_invites 
        ADD CONSTRAINT assistant_invites_contact_check 
        CHECK (invited_email IS NOT NULL OR invited_phone IS NOT NULL);
    END IF;
END $$;
-- Table and Column Descriptions
COMMENT ON TABLE public.assistant_invites IS 'Manages the onboarding process for assistants. Stores invitation tokens sent via email or phone, linked to a specific psychologist. Invites have a deadline (expires_at) and can be revoked manually.';
COMMENT ON COLUMN public.assistant_invites.id IS 'Unique identifier for the invite (token).';
COMMENT ON COLUMN public.assistant_invites.invited_email IS 'Email address where the invitation was sent. Optional if phone is provided.';
COMMENT ON COLUMN public.assistant_invites.invited_phone IS 'Phone number (WhatsApp) where the invitation was sent. Optional if email is provided.';
COMMENT ON COLUMN public.assistant_invites.psychologist_id IS 'The ID of the psychologist who owns the data and is issuing the invitation.';
COMMENT ON COLUMN public.assistant_invites.expires_at IS 'Deadline for the invite to be accepted. After this, the token is invalid.';
COMMENT ON COLUMN public.assistant_invites.accepted_at IS 'Timestamp when the assistant accepted the invitation and was linked to the psychologist.';
COMMENT ON COLUMN public.assistant_invites.revoked_at IS 'Timestamp if the psychologist cancelled the invite before it was accepted or expired.';
COMMENT ON COLUMN public.assistant_invites.metadata IS 'Additional context for the invite (e.g., invitation channel, language, etc.).';
-------------------------------------------------------------------------------
-- 3. PSYCHOLOGIST ASSISTANTS
-------------------------------------------------------------------------------

-- Add revoked_at and metadata for access control
ALTER TABLE public.psychologist_assistants 
ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
-- Ensure only one active relationship exists per psychologist/assistant pair
-- This allows an assistant to work for multiple psychologists, 
-- but only have one active (non-revoked) record for each.
CREATE UNIQUE INDEX IF NOT EXISTS psychologist_assistants_active_unique_idx 
ON public.psychologist_assistants (psychologist_id, assistant_id) 
WHERE (revoked_at IS NULL);
-- Table and Column Descriptions
COMMENT ON TABLE public.psychologist_assistants IS 'Active and historical relationships between psychologists and their assistants. This table is the source of truth for data access permissions.';
COMMENT ON COLUMN public.psychologist_assistants.psychologist_id IS 'The owner of the clinical data (the psychologist).';
COMMENT ON COLUMN public.psychologist_assistants.assistant_id IS 'The user granted access to act as an assistant.';
COMMENT ON COLUMN public.psychologist_assistants.revoked_at IS 'Timestamp when the assistant''s access was terminated by the psychologist. If NULL, access is active.';
COMMENT ON COLUMN public.psychologist_assistants.created_at IS 'Timestamp when the assistant relationship was established (usually via invite acceptance).';
COMMENT ON COLUMN public.psychologist_assistants.metadata IS 'Additional relationship context (e.g., origin invite ID, notes, etc.).';
-------------------------------------------------------------------------------
-- 4. ADMINS
-------------------------------------------------------------------------------

-- Add is_active and permissions array for granular control
ALTER TABLE public.admins 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS permissions TEXT[] DEFAULT '{}'::text[],
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
-- Table and Column Descriptions
COMMENT ON TABLE public.admins IS 'Internal Fluri administrators who manage the platform ecosystem (activities, templates, global catalogs). Access is typically granted via admin.fluri.com.br.';
COMMENT ON COLUMN public.admins.id IS 'Unique identifier for the admin, linking to auth.users.';
COMMENT ON COLUMN public.admins.first_name IS 'Admin''s first name for internal identification.';
COMMENT ON COLUMN public.admins.last_name IS 'Admin''s last name for internal identification.';
COMMENT ON COLUMN public.admins.is_active IS 'Flag to enable or disable admin access without deleting the record.';
COMMENT ON COLUMN public.admins.permissions IS 'Array of specific permission strings (e.g., "manage_activities", "edit_templates") for granular access control.';
COMMENT ON COLUMN public.admins.metadata IS 'Flexible storage for admin-specific settings or future metadata.';
-------------------------------------------------------------------------------
-- 5. SUBSCRIPTION PLANS (Neutralized Name, Specific Columns)
-------------------------------------------------------------------------------

-- Rename table to be provider-agnostic
ALTER TABLE IF EXISTS public.stripe_price_plans RENAME TO subscription_plans;
-- Rename plan_id to subscription_plan_id for clarity
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'subscription_plans'
      AND column_name = 'plan_id'
  ) THEN
    ALTER TABLE public.subscription_plans RENAME COLUMN plan_id TO subscription_plan_id;
  END IF;
END $$;
-- Backward-compatible shape for environments where legacy columns never existed.
ALTER TABLE public.subscription_plans
  ADD COLUMN IF NOT EXISTS subscription_plan_id TEXT,
  ADD COLUMN IF NOT EXISTS plan_name TEXT,
  ADD COLUMN IF NOT EXISTS features JSONB DEFAULT '{}'::jsonb;
UPDATE public.subscription_plans
SET
  subscription_plan_id = COALESCE(subscription_plan_id, id),
  plan_name = COALESCE(plan_name, name),
  features = COALESCE(features, metadata, '{}'::jsonb);
-- Table and Column Descriptions
COMMENT ON TABLE public.subscription_plans IS 'Catalog of available subscription plans. Defines base features and limits. Provider-agnostic table name with provider-specific columns.';
COMMENT ON COLUMN public.subscription_plans.subscription_plan_id IS 'Internal slug for the plan (e.g., "basic", "pro", "premium").';
COMMENT ON COLUMN public.subscription_plans.plan_name IS 'Display name of the plan.';
COMMENT ON COLUMN public.subscription_plans.stripe_price_id IS 'The ID of the price/plan in Stripe (Clover v2 API).';
COMMENT ON COLUMN public.subscription_plans.features IS 'JSONB containing base entitlements and quotas. Example: {"can_use_ai": true, "max_patients": 50}.';
-------------------------------------------------------------------------------
-- 6. PSYCHOLOGIST SUBSCRIPTIONS (Single State per User)
-------------------------------------------------------------------------------

-- Ensure only one subscription record exists per psychologist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'psychologist_subscriptions_psychologist_id_key') THEN
        ALTER TABLE public.psychologist_subscriptions ADD CONSTRAINT psychologist_subscriptions_psychologist_id_key UNIQUE (psychologist_id);
    END IF;
END $$;
-- Rename plan_id to subscription_plan_id for clarity
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'psychologist_subscriptions'
      AND column_name = 'plan_id'
  ) THEN
    ALTER TABLE public.psychologist_subscriptions RENAME COLUMN plan_id TO subscription_plan_id;
  END IF;
END $$;
-- Table and Column Descriptions
COMMENT ON TABLE public.psychologist_subscriptions IS 'Current subscription state for each psychologist. Only one record per user. References Stripe Clover v2 IDs.';
COMMENT ON COLUMN public.psychologist_subscriptions.psychologist_id IS 'The ID of the psychologist who owns this subscription.';
COMMENT ON COLUMN public.psychologist_subscriptions.stripe_subscription_id IS 'The subscription identifier in Stripe (Clover v2 API).';
COMMENT ON COLUMN public.psychologist_subscriptions.stripe_price_id IS 'The current price/plan identifier in Stripe.';
COMMENT ON COLUMN public.psychologist_subscriptions.status IS 'Current status of the subscription (e.g., active, trialing, past_due, canceled).';
COMMENT ON COLUMN public.psychologist_subscriptions.has_active_subscription IS 'Boolean flag for quick access check (true if status is active or trialing).';
COMMENT ON COLUMN public.psychologist_subscriptions.metadata IS 'Used for specific overrides. Schema: {"overrides": {"permissions": ["extra_feat"], "quotas": {"max_patients": 100}}}.';
-------------------------------------------------------------------------------
-- 7. PSYCHOLOGISTS (Core Profile & Payment Identity)
-------------------------------------------------------------------------------

COMMENT ON TABLE public.psychologists IS 'Core profile data for psychologists. Acts as the primary identity for both clinical and payment (Stripe Clover v2) contexts.';
COMMENT ON COLUMN public.psychologists.stripe_customer_id IS 'The primary Stripe identity for the psychologist (Clover v2 Customer ID). Used for both paying their own subscription and receiving payments via Connect.';
COMMENT ON COLUMN public.psychologists.stripe_subscription_id IS 'Redundant reference to the current active subscription ID for performance in simple queries.';
COMMENT ON COLUMN public.psychologists.subscription_status IS 'Current status of the psychologist''s own subscription.';
-------------------------------------------------------------------------------
-- 8. AUDIT LOGS
-------------------------------------------------------------------------------

-- Add correlation_id for distributed tracing
ALTER TABLE public.audit_logs 
ADD COLUMN IF NOT EXISTS correlation_id UUID DEFAULT gen_random_uuid();
-- Table and Column Descriptions
COMMENT ON TABLE public.audit_logs IS 'Central repository for security and operational auditing. Tracks who changed what, when, and from where. Crucial for healthcare compliance (LGPD).';
COMMENT ON COLUMN public.audit_logs.id IS 'Unique identifier for the audit log entry.';
COMMENT ON COLUMN public.audit_logs.user_id IS 'The ID of the user (psychologist, assistant, or admin) who performed the action.';
COMMENT ON COLUMN public.audit_logs.user_type IS 'The category of the user (e.g., "psychologist", "assistant", "admin").';
COMMENT ON COLUMN public.audit_logs.table_name IS 'The name of the database table affected by the change.';
COMMENT ON COLUMN public.audit_logs.record_id IS 'The primary key of the specific record that was changed.';
COMMENT ON COLUMN public.audit_logs.action IS 'The type of operation performed: INSERT, UPDATE, DELETE, or ACCESS.';
COMMENT ON COLUMN public.audit_logs.changed_fields IS 'JSONB containing the delta of the change (e.g., {"old": {...}, "new": {...}}).';
COMMENT ON COLUMN public.audit_logs.ip_address IS 'The IP address of the user at the time of the action.';
COMMENT ON COLUMN public.audit_logs.user_agent IS 'The browser or device string used to perform the action.';
COMMENT ON COLUMN public.audit_logs.correlation_id IS 'Unique ID to correlate this log entry with application-level logs or background jobs.';
COMMENT ON COLUMN public.audit_logs.created_at IS 'Timestamp when the audit log entry was created.';
-------------------------------------------------------------------------------
-- 9. PSYCHOLOGIST AVAILABILITY & SCHEDULING (Rearchitecture)
-------------------------------------------------------------------------------

-- 9.1. Unify weekly availability into a single source of truth
ALTER TABLE IF EXISTS public.psychologist_availability RENAME TO psychologist_weekly_schedules;
DROP TABLE IF EXISTS public.weekly_availability_configs;
-- 9.2. Add Slotting Constraint (Multiples of 30 or 60 minutes)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'psychologist_weekly_schedules_slot_check') THEN
        ALTER TABLE public.psychologist_weekly_schedules 
        ADD CONSTRAINT psychologist_weekly_schedules_slot_check 
        CHECK (
            EXTRACT(MINUTE FROM start_time) IN (0, 30) AND 
            EXTRACT(SECOND FROM start_time) = 0
        );
    END IF;
END $$;
-- 9.3. Add Overlap Prevention in busy_slots (No-Double-Booking)
CREATE EXTENSION IF NOT EXISTS btree_gist;
-- Note: We are commenting out the EXCLUDE constraint for now because existing data 
-- in the remote database has overlaps. This should be applied after data cleanup.
/*
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'psychologist_no_overlap') THEN
        ALTER TABLE public.busy_slots 
        ADD CONSTRAINT psychologist_no_overlap 
        EXCLUDE USING gist (psychologist_id WITH =, slot_range WITH &&);
    END IF;
END $$;
*/

-- 9.4. Table and Column Descriptions (English)
COMMENT ON TABLE public.psychologist_weekly_schedules IS 'Defines recurring weekly working hours for a psychologist.';
COMMENT ON TABLE public.availability_exceptions IS 'Overrides for specific dates (holidays, vacations).';
COMMENT ON TABLE public.busy_slots IS 'Ultimate source of truth for time blocking. Prevents double-booking.';
-------------------------------------------------------------------------------
-- 10. CALENDAR EVENT TYPE CLEANUP
-------------------------------------------------------------------------------

-- 10.1. Create new ENUM without 'task'
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'calendar_event_type_new') THEN
        CREATE TYPE public.calendar_event_type_new AS ENUM ('session', 'supervision', 'meeting', 'block', 'other');
    END IF;
END $$;
-- 10.2. Update calendar_events and calendar_event_series
-- Note: Temporarily disabled due to dependency on calendar_events_full view.
-- This requires dropping and recreating the view.
/*
UPDATE public.calendar_events SET event_type = 'other'::public.calendar_event_type WHERE event_type::text = 'task';
ALTER TABLE public.calendar_events ALTER COLUMN event_type TYPE public.calendar_event_type_new USING event_type::text::public.calendar_event_type_new;

UPDATE public.calendar_event_series SET event_type = 'other'::public.calendar_event_type WHERE event_type::text = 'task';
ALTER TABLE public.calendar_event_series ALTER COLUMN event_type TYPE public.calendar_event_type_new USING event_type::text::public.calendar_event_type_new;

-- 10.3. Replace the old ENUM
DROP TYPE public.calendar_event_type;
ALTER TYPE public.calendar_event_type_new RENAME TO calendar_event_type;
*/

-------------------------------------------------------------------------------
-- 11. CATALOGS & REFERENCE DATA RESTRUCTURING
-------------------------------------------------------------------------------

-- 11.1. Create a unified Reference Values table
CREATE TABLE IF NOT EXISTS public.reference_values (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category TEXT NOT NULL,
    label_pt TEXT NOT NULL,
    value TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS reference_values_category_value_idx ON public.reference_values (category, value);
-- 11.2. Rename Rich Catalogs
ALTER TABLE IF EXISTS public.clinical_activities_catalog RENAME TO catalog_clinical_activities;
ALTER TABLE IF EXISTS public.document_templates RENAME TO catalog_document_templates;
ALTER TABLE IF EXISTS public.interview_templates RENAME TO catalog_interview_templates;
-- 11.3. Cleanup Unused/Empty Tables
DROP TABLE IF EXISTS public.medications_catalog CASCADE;
DROP TABLE IF EXISTS public.medication_terms CASCADE;
DROP TABLE IF EXISTS public.medication_dosages CASCADE;
DROP TABLE IF EXISTS public.psychological_disorders_catalog CASCADE;
DROP TABLE IF EXISTS public.global_tags CASCADE;
DROP TABLE IF EXISTS public.psychology_specialties_catalog CASCADE;
DROP TABLE IF EXISTS public.psychological_approaches_catalog CASCADE;
DROP TABLE IF EXISTS public.session_cancellation_policies_catalog CASCADE;
DROP TABLE IF EXISTS public.financial_transaction_categories CASCADE;
DROP TABLE IF EXISTS public.psychological_services_catalog CASCADE;
-------------------------------------------------------------------------------
-- 12. CANCELLATION POLICIES
-------------------------------------------------------------------------------

ALTER TABLE IF EXISTS public.session_cancellation_policies_catalog RENAME TO catalog_cancellation_policies;
-- Refine psychologist_session_cancellation_policy for Versioning
ALTER TABLE public.psychologist_session_cancellation_policy DROP COLUMN IF EXISTS notes;
ALTER TABLE public.psychologist_session_cancellation_policy ADD COLUMN IF NOT EXISTS effective_until TIMESTAMP WITH TIME ZONE;
CREATE UNIQUE INDEX IF NOT EXISTS psychologist_session_cancellation_policy_active_idx 
ON public.psychologist_session_cancellation_policy (psychologist_id) WHERE (effective_until IS NULL);
-- Trigger to automatically close previous policy
CREATE OR REPLACE FUNCTION public.fn_close_previous_cancellation_policy()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    UPDATE public.psychologist_session_cancellation_policy
    SET effective_until = NOW()
    WHERE psychologist_id = NEW.psychologist_id AND effective_until IS NULL AND id <> NEW.id;
    RETURN NEW;
END;
$$;
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_close_previous_cancellation_policy') THEN
        CREATE TRIGGER tr_close_previous_cancellation_policy BEFORE INSERT ON public.psychologist_session_cancellation_policy
        FOR EACH ROW EXECUTE FUNCTION public.fn_close_previous_cancellation_policy();
    END IF;
END $$;
-------------------------------------------------------------------------------
-- 13. CLINICAL SESSIONS & AUTOMATION
-------------------------------------------------------------------------------

ALTER TABLE IF EXISTS public.clinical_sessions RENAME TO psychologist_clinical_sessions;
ALTER TABLE public.psychologist_clinical_sessions 
ADD COLUMN IF NOT EXISTS calendar_event_id UUID REFERENCES public.calendar_events(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS session_number INTEGER,
ADD COLUMN IF NOT EXISTS attendance_confirmed BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS confirmation_sent_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS billing_status TEXT,
ADD COLUMN IF NOT EXISTS billing_next_attempt_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS billing_attempt_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS billing_last_error TEXT,
ADD COLUMN IF NOT EXISTS automation_metadata JSONB DEFAULT '{}'::jsonb;
-- 14.3. Cleanup: Drop the redundant details table
-- Note: Temporarily disabled due to dependency on calendar_events_full view.
/*
DROP TABLE IF EXISTS public.clinical_session_details;
*/

-------------------------------------------------------------------------------
-- 14. PSYCHOLOGIST NOTES (Refinement)
-------------------------------------------------------------------------------

ALTER TABLE IF EXISTS public.clinical_notes RENAME TO psychologist_notes;
ALTER TABLE public.psychologist_notes RENAME COLUMN related_evolution_id TO parent_note_id;
ALTER TABLE public.psychologist_notes DROP COLUMN IF EXISTS updated_by;
CREATE UNIQUE INDEX IF NOT EXISTS psychologist_notes_ai_child_unique_idx 
ON public.psychologist_notes (parent_note_id) WHERE (parent_note_id IS NOT NULL);
-------------------------------------------------------------------------------
-- 15. PUBLIC PROFILE & MARKETPLACE (Unification)
-------------------------------------------------------------------------------

ALTER TABLE IF EXISTS public.psychologist_profiles RENAME TO public_profiles;
DROP TABLE IF EXISTS public.marketplace_psychologist_profiles CASCADE;
ALTER TABLE IF EXISTS public.linktree_links RENAME TO public_linktree_links;
DROP TABLE IF EXISTS public.marketplace_linktree_links CASCADE;
ALTER TABLE IF EXISTS public.psychologist_locations RENAME TO public_locations;
DROP TABLE IF EXISTS public.marketplace_locations CASCADE;
ALTER TABLE IF EXISTS public.marketplace_payment_intents RENAME TO public_client_checkout_intents;
-------------------------------------------------------------------------------
-- 16. PATIENT TERMINOLOGY & INTERVENTION UNIFICATION
-------------------------------------------------------------------------------

-- 16.1. Standardize on "Patient" terminology
ALTER TABLE IF EXISTS public.psychologist_clients RENAME TO psychologist_patients;
ALTER TABLE IF EXISTS public.psychologist_client_charges RENAME TO psychologist_patient_charges;
ALTER TABLE IF EXISTS public.psychologist_client_services RENAME TO psychologist_patient_services;
-- 16.2. Unify Activities and Responses
ALTER TABLE IF EXISTS public.patient_activity_assignments RENAME TO psychologist_patient_activities;
ALTER TABLE public.psychologist_patient_activities ADD COLUMN IF NOT EXISTS response_data JSONB, ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMP WITH TIME ZONE;
DROP TABLE IF EXISTS public.patient_activity_responses CASCADE;
-- 16.3. Rename other patient tables
ALTER TABLE IF EXISTS public.patient_tests RENAME TO psychologist_patient_assessments;
ALTER TABLE IF EXISTS public.patient_emergency_contacts RENAME TO psychologist_patient_emergency_contacts;
-- 16.4. Cleanup
DROP TABLE IF EXISTS public.patient_timeline_events CASCADE;
-------------------------------------------------------------------------------
-- 17. FINANCIAL REFINEMENT & ATTACHMENTS
-------------------------------------------------------------------------------

-- 17.1. Unify Transaction Attachments
ALTER TABLE public.psychologist_financial_entries ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE public.psychologist_patient_charges ADD COLUMN IF NOT EXISTS attachment_url TEXT;
DROP TABLE IF EXISTS public.transaction_attachments CASCADE;
-------------------------------------------------------------------------------
-- 18. PSYCHOLOGIST PREFERENCES
-------------------------------------------------------------------------------

ALTER TABLE IF EXISTS public.user_preferences RENAME TO psychologist_preferences;
ALTER TABLE IF EXISTS public.user_preferences_audit_log RENAME TO psychologist_preferences_audit_log;
