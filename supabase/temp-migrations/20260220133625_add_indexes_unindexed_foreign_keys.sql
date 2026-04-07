-- ============================================================================
-- Add covering indexes for unindexed foreign keys (Supabase linter 0001)
-- Purpose: Improve query performance for FK lookups and JOINs.
-- Applied: Local only. Do not push to remote unless intended.
-- ============================================================================

begin;
-- assistant_invites
create index if not exists idx_assistant_invites_psychologist_id
  on public.assistant_invites (psychologist_id);
-- availability_exceptions
create index if not exists idx_availability_exceptions_psychologist_id
  on public.availability_exceptions (psychologist_id);
-- calendar_event_series
create index if not exists idx_calendar_event_series_psychologist_id
  on public.calendar_event_series (psychologist_id);
-- clinical_session_details
-- NOTE:
-- Table was removed from current canonical schema. Keep this migration compatible
-- with environments where it no longer exists.
do $$
begin
  if to_regclass('public.clinical_session_details') is not null then
    create index if not exists idx_clinical_session_details_clinical_session_id
      on public.clinical_session_details (clinical_session_id);
    create index if not exists idx_clinical_session_details_patient_id
      on public.clinical_session_details (patient_id);
    create index if not exists idx_clinical_session_details_psychologist_client_id
      on public.clinical_session_details (psychologist_client_id);
    create index if not exists idx_clinical_session_details_psychologist_service_id
      on public.clinical_session_details (psychologist_service_id);
    create index if not exists idx_clinical_session_details_session_type_id
      on public.clinical_session_details (session_type_id);
  end if;
end $$;
-- financial_categories
create index if not exists idx_financial_categories_psychologist_id
  on public.financial_categories (psychologist_id);
-- generated_documents
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'generated_documents'
      and column_name = 'patient_id'
  ) then
    create index if not exists idx_generated_documents_patient_id
      on public.generated_documents (patient_id);
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'generated_documents'
      and column_name = 'psychologist_client_id'
  ) then
    create index if not exists idx_generated_documents_psychologist_client_id
      on public.generated_documents (psychologist_client_id);
  end if;
end $$;
create index if not exists idx_generated_documents_psychologist_id
  on public.generated_documents (psychologist_id);
-- google_sync_logs
create index if not exists idx_google_sync_logs_calendar_event_id
  on public.google_sync_logs (calendar_event_id);
create index if not exists idx_google_sync_logs_psychologist_id
  on public.google_sync_logs (psychologist_id);
create index if not exists idx_google_sync_logs_series_id
  on public.google_sync_logs (series_id);
-- psychologist_clinical_sessions
create index if not exists idx_psychologist_clinical_sessions_psychologist_id
  on public.psychologist_clinical_sessions (psychologist_id);
create index if not exists idx_psychologist_clinical_sessions_psychologist_patient_id
  on public.psychologist_clinical_sessions (psychologist_patient_id);
create index if not exists idx_psychologist_clinical_sessions_calendar_event_id
  on public.psychologist_clinical_sessions (calendar_event_id);
-- psychologist_financial_entries
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_financial_entries'
      and column_name = 'billing_id'
  ) then
    create index if not exists idx_psychologist_financial_entries_billing_id
      on public.psychologist_financial_entries (billing_id);
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_financial_entries'
      and column_name = 'charge_id'
  ) then
    create index if not exists idx_psychologist_financial_entries_charge_id
      on public.psychologist_financial_entries (charge_id);
  end if;
end $$;
create index if not exists idx_psychologist_financial_entries_psychologist_id
  on public.psychologist_financial_entries (psychologist_id);
create index if not exists idx_psychologist_financial_entries_session_id
  on public.psychologist_financial_entries (session_id);
-- psychologist_notes
create index if not exists idx_psychologist_notes_psychologist_id
  on public.psychologist_notes (psychologist_id);
create index if not exists idx_psychologist_notes_patient_id
  on public.psychologist_notes (patient_id);
create index if not exists idx_psychologist_notes_session_id
  on public.psychologist_notes (session_id);
-- psychologist_patient_activities
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_patient_activities'
      and column_name = 'patient_id'
  ) then
    create index if not exists idx_psychologist_patient_activities_patient_id
      on public.psychologist_patient_activities (patient_id);
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_patient_activities'
      and column_name = 'psychologist_client_id'
  ) then
    create index if not exists idx_psychologist_patient_activities_psychologist_client_id
      on public.psychologist_patient_activities (psychologist_client_id);
  end if;
end $$;
create index if not exists idx_psychologist_patient_activities_psychologist_id
  on public.psychologist_patient_activities (psychologist_id);
-- psychologist_patient_assessments
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_patient_assessments'
      and column_name = 'patient_id'
  ) then
    create index if not exists idx_psychologist_patient_assessments_patient_id
      on public.psychologist_patient_assessments (patient_id);
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_patient_assessments'
      and column_name = 'psychologist_client_id'
  ) then
    create index if not exists idx_psychologist_patient_assessments_psychologist_client_id
      on public.psychologist_patient_assessments (psychologist_client_id);
  end if;
end $$;
create index if not exists idx_psychologist_patient_assessments_psychologist_id
  on public.psychologist_patient_assessments (psychologist_id);
-- psychologist_patient_charges
create index if not exists idx_psychologist_patient_charges_psychologist_id
  on public.psychologist_patient_charges (psychologist_id);
create index if not exists idx_psychologist_patient_charges_psychologist_patient_id
  on public.psychologist_patient_charges (psychologist_patient_id);
-- psychologist_patient_services (column renamed from psychologist_client_id to psychologist_patient_id)
create index if not exists idx_psychologist_patient_services_psychologist_patient_id
  on public.psychologist_patient_services (psychologist_patient_id);
-- psychologist_patients
create index if not exists idx_psychologist_patients_patient_id
  on public.psychologist_patients (patient_id);
-- psychologist_subscriptions
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_subscriptions'
      and column_name = 'psychologist_id'
  ) then
    create index if not exists idx_psychologist_subscriptions_psychologist_id
      on public.psychologist_subscriptions (psychologist_id);
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'psychologist_subscriptions'
      and column_name = 'therapist_id'
  ) then
    create index if not exists idx_psychologist_subscriptions_therapist_id
      on public.psychologist_subscriptions (therapist_id);
  end if;
end $$;
-- psychologist_weekly_schedules
create index if not exists idx_psychologist_weekly_schedules_location_id
  on public.psychologist_weekly_schedules (location_id);
create index if not exists idx_psychologist_weekly_schedules_psychologist_id
  on public.psychologist_weekly_schedules (psychologist_id);
-- public_client_checkout_intents (column renamed from psychologist_client_id to psychologist_patient_id)
create index if not exists idx_public_client_checkout_intents_psychologist_patient_id
  on public.public_client_checkout_intents (psychologist_patient_id);
create index if not exists idx_public_client_checkout_intents_session_id
  on public.public_client_checkout_intents (session_id);
-- public_linktree_links
create index if not exists idx_public_linktree_links_psychologist_id
  on public.public_linktree_links (psychologist_id);
-- public_locations
create index if not exists idx_public_locations_psychologist_id
  on public.public_locations (psychologist_id);
-- session_reschedule_requests
create index if not exists idx_session_reschedule_requests_initiated_by
  on public.session_reschedule_requests (initiated_by);
create index if not exists idx_session_reschedule_requests_responded_by
  on public.session_reschedule_requests (responded_by);
create index if not exists idx_session_reschedule_requests_session_id
  on public.session_reschedule_requests (session_id);
-- sync_conflict_resolutions
create index if not exists idx_sync_conflict_resolutions_event_id
  on public.sync_conflict_resolutions (event_id);
create index if not exists idx_sync_conflict_resolutions_psychologist_id
  on public.sync_conflict_resolutions (psychologist_id);
commit;
