-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-20T16:11:33Z

-- Reconcile local schema with known production columns from remote snapshot.
-- Safety: additive-only migration (no drops/type rewrites), idempotent via IF NOT EXISTS.

-- 1) public_locations: prod includes complement.
alter table if exists public.public_locations
  add column if not exists complement text;
comment on column public.public_locations.complement is
  'Address complement (aligned with production schema).';
-- 2) google_calendar_connections: prod includes watch_channel_token and auto_create_meet_for_sessions.
alter table if exists public.google_calendar_connections
  add column if not exists watch_channel_token text,
  add column if not exists auto_create_meet_for_sessions boolean not null default true;
comment on column public.google_calendar_connections.watch_channel_token is
  'Opaque token used to validate Google watch notifications.';
comment on column public.google_calendar_connections.auto_create_meet_for_sessions is
  'Whether session events should auto-create Google Meet links by default.';
-- 3) catalog_clinical_activities: prod has richer catalog metadata fields.
alter table if exists public.catalog_clinical_activities
  add column if not exists activity_kind text,
  add column if not exists duration_min integer,
  add column if not exists goals text[],
  add column if not exists populations text[],
  add column if not exists delivery_modes text[],
  add column if not exists materials_json jsonb,
  add column if not exists clinician_notes_template text,
  add column if not exists risk_level text,
  add column if not exists tags text[];
comment on column public.catalog_clinical_activities.activity_kind is
  'Activity classification/kind from production catalog.';
comment on column public.catalog_clinical_activities.duration_min is
  'Suggested activity duration in minutes.';
comment on column public.catalog_clinical_activities.goals is
  'Structured goals list for activity prescription.';
comment on column public.catalog_clinical_activities.populations is
  'Target populations for activity use.';
comment on column public.catalog_clinical_activities.delivery_modes is
  'Allowed delivery modes (in-person/online/etc).';
comment on column public.catalog_clinical_activities.materials_json is
  'Supplemental structured materials metadata.';
comment on column public.catalog_clinical_activities.clinician_notes_template is
  'Template text for clinician guidance notes.';
comment on column public.catalog_clinical_activities.risk_level is
  'Risk level metadata for activity usage context.';
comment on column public.catalog_clinical_activities.tags is
  'Tag labels used for filtering/catalog navigation.';
-- 4) public_profiles: add production profile fields missing locally (additive only).
alter table if exists public.public_profiles
  add column if not exists display_name_linktree text,
  add column if not exists education jsonb,
  add column if not exists certificates jsonb,
  add column if not exists gender text,
  add column if not exists date_of_birth date,
  add column if not exists marital_status text,
  add column if not exists ethnicity text,
  add column if not exists cpf text,
  add column if not exists rqe text,
  add column if not exists linkedin_url text,
  add column if not exists instagram_url text,
  add column if not exists website_url text,
  add column if not exists youtube_url text,
  add column if not exists whatsapp_url text,
  add column if not exists telegram_url text,
  add column if not exists service_values jsonb,
  add column if not exists education_records jsonb;
comment on column public.public_profiles.display_name_linktree is
  'Optional public-facing display name variant used by link pages.';
comment on column public.public_profiles.service_values is
  'Structured pricing/service payload as used in production profile schema.';
comment on column public.public_profiles.education_records is
  'Structured education history records as used in production profile schema.';
