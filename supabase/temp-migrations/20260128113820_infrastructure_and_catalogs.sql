DO $$ BEGIN CREATE TYPE public.calendar_event_type AS ENUM ('session',       
      'supervision',   
      'meeting',       
      'task',          
      'block',         
      'other'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.calendar_event_status AS ENUM ('scheduled',
      'confirmed',
      'in_progress',
      'completed',
      'cancelled',
      'no_show',
      'rescheduled'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.calendar_event_source AS ENUM ('fluri',
      'google'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.supervision_type AS ENUM ('giving',    
      'receiving'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.block_type AS ENUM ('lunch',
      'break',
      'vacation',
      'personal',
      'unavailable'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.google_sync_status AS ENUM ('pending',
      'synced',
      'error',
      'not_synced'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.sync_direction AS ENUM ('fluri_to_google',
      'google_to_fluri'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.sync_operation AS ENUM ('create',
      'update',
      'delete'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.sync_result_status AS ENUM ('success',
      'error',
      'skipped'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE public.series_exception_type AS ENUM ('cancelled',
      'rescheduled',
      'modified'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
CREATE OR REPLACE FUNCTION public.validate_weekly_availability_overlaps(
  p_psychologist_id uuid,
  p_day_of_week integer,
  p_intervals jsonb
)
RETURNS TABLE (
  has_overlap boolean,
  overlap_details text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  WITH intervals AS (
    SELECT 
      (value->>'startTime')::time as start_time,
      (value->>'endTime')::time as end_time
    FROM jsonb_array_elements(p_intervals)
  )
  SELECT 
    true,
    format('Overlap between %s-%s and %s-%s', i1.start_time, i1.end_time, i2.start_time, i2.end_time)
  FROM intervals i1
  JOIN intervals i2 ON i1.start_time < i2.end_time AND i2.start_time < i1.end_time
  WHERE i1.start_time != i2.start_time OR i1.end_time != i2.end_time
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::text;
  END IF;
END;
$$;
BEGIN;
INSERT INTO storage.buckets (id, name, public)
VALUES ('linktree', 'linktree', true)
ON CONFLICT (id) DO UPDATE SET public = true;
INSERT INTO storage.buckets (id, name, public)
VALUES ('test-results', 'test-results', false)
ON CONFLICT (id) DO UPDATE SET public = false;
SELECT cron.schedule(
  'trigger-process-sync-queue',
  '*/5 * * * *',
  $$SELECT net.http_post(
      url := 'https://ecilqoemhxilnddugrql.supabase.co/functions/v1/trigger-process-sync-queue',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)),
      body := '{}'
  );$$
);
SELECT cron.schedule(
  'trigger-periodic-sync',
  '0 */6 * * *',
  $$SELECT net.http_post(
      url := 'https://ecilqoemhxilnddugrql.supabase.co/functions/v1/trigger-periodic-sync',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)),
      body := '{}'
  );$$
);
SELECT cron.schedule(
  'trigger-renew-watch-channels',
  '0 2 */2 * *',
  $$SELECT net.http_post(
      url := 'https://ecilqoemhxilnddugrql.supabase.co/functions/v1/trigger-renew-watch-channels',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)),
      body := '{}'
  );$$
);
COMMIT;
create table if not exists public.google_calendar_connections (
  id uuid primary key default gen_random_uuid(),
  psychologist_id uuid not null references public.psychologists(id) on delete cascade,
  
  
  access_token text not null,
  refresh_token text not null,
  token_expires_at timestamptz not null,
  
  
  google_email text not null,
  google_calendar_id text not null default 'primary',
  
  
  sync_enabled boolean not null default true,
  sync_to_google boolean not null default true,
  sync_from_google boolean not null default true,
  
  
  sync_sessions boolean not null default true,
  sync_supervisions boolean not null default true,
  sync_meetings boolean not null default true,
  sync_tasks boolean not null default false,
  sync_blocks boolean not null default true,
  sync_other boolean not null default false,
  
  
  show_patient_name boolean not null default false,  
  show_event_details boolean not null default false, 
  
  
  watch_channel_id text,
  watch_resource_id text,
  watch_expiration timestamptz,
  
  
  is_connected boolean not null default true,
  last_sync_at timestamptz,
  last_sync_error text,
  
  
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  
  constraint unique_psychologist_google_connection unique (psychologist_id)
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_google_cal_conn_psychologist on public.google_calendar_connections(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_google_cal_conn_watch_channel on public.google_calendar_connections(watch_channel_id) where watch_channel_id is not null; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_calendar_connections' AND schemaname = 'public') THEN alter table public.google_calendar_connections enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_calendar_connections' AND schemaname = 'public') THEN create policy "Psychologists can view own connection"
  on public.google_calendar_connections for select
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_calendar_connections' AND schemaname = 'public') THEN create policy "Psychologists can insert own connection"
  on public.google_calendar_connections for insert
  with check (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_calendar_connections' AND schemaname = 'public') THEN create policy "Psychologists can update own connection"
  on public.google_calendar_connections for update
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_calendar_connections' AND schemaname = 'public') THEN create policy "Psychologists can delete own connection"
  on public.google_calendar_connections for delete
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create table if not exists public.calendar_event_series (
  id uuid primary key default gen_random_uuid(),
  psychologist_id uuid not null references public.psychologists(id) on delete cascade,
  
  
  event_type public.calendar_event_type not null,
  title text not null,
  description text,
  location text,
  color text, 
  
  
  start_time time not null,           
  end_time time not null,             
  duration_minutes integer not null default 50,
  timezone text not null default 'America/Sao_Paulo',
  all_day boolean not null default false,
  
  
  rrule text not null,                
  effective_start date not null,      
  effective_end date,                 
  
  
  google_event_id text,               
  google_sync_status public.google_sync_status not null default 'not_synced',
  
  
  metadata jsonb default '{}',        
  
  
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  
  constraint valid_time_range check (start_time < end_time),
  constraint valid_duration check (duration_minutes > 0)
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_event_series_psychologist on public.calendar_event_series(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_event_series_type on public.calendar_event_series(event_type); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_event_series_effective on public.calendar_event_series(effective_start, effective_end); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series' AND schemaname = 'public') THEN alter table public.calendar_event_series enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series' AND schemaname = 'public') THEN create policy "Psychologists can view own series"
  on public.calendar_event_series for select
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series' AND schemaname = 'public') THEN create policy "Psychologists can insert own series"
  on public.calendar_event_series for insert
  with check (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series' AND schemaname = 'public') THEN create policy "Psychologists can update own series"
  on public.calendar_event_series for update
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series' AND schemaname = 'public') THEN create policy "Psychologists can delete own series"
  on public.calendar_event_series for delete
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  psychologist_id uuid not null references public.psychologists(id) on delete cascade,
  series_id uuid references public.calendar_event_series(id) on delete set null,
  
  
  event_type public.calendar_event_type not null,
  title text not null,
  description text,
  location text,
  color text,
  
  
  start_datetime timestamptz not null,
  end_datetime timestamptz not null,
  duration_minutes integer not null,
  timezone text not null default 'America/Sao_Paulo',
  all_day boolean not null default false,
  
  
  original_start_datetime timestamptz,
  original_end_datetime timestamptz,
  
  
  status public.calendar_event_status not null default 'scheduled',
  source public.calendar_event_source not null default 'fluri',
  
  
  google_event_id text,
  google_sync_status public.google_sync_status not null default 'not_synced',
  google_sync_error text,
  last_synced_at timestamptz,
  
  
  
  
  
  
  
  metadata jsonb not null default '{}',
  
  
  private_notes text,
  
  
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  
  constraint valid_datetime_range check (start_datetime < end_datetime)
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_calendar_events_psychologist on public.calendar_events(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_calendar_events_type on public.calendar_events(event_type); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_calendar_events_status on public.calendar_events(status); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_calendar_events_series on public.calendar_events(series_id) where series_id is not null; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_calendar_events_datetime on public.calendar_events(start_datetime, end_datetime); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_calendar_events_google on public.calendar_events(google_event_id) where google_event_id is not null; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_calendar_events_sync_status on public.calendar_events(google_sync_status) where google_sync_status = 'pending'; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_calendar_events_metadata on public.calendar_events using gin (metadata); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN alter table public.calendar_events enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN create policy "Psychologists can view own events"
  on public.calendar_events for select
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN create policy "Psychologists can insert own events"
  on public.calendar_events for insert
  with check (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN create policy "Psychologists can update own events"
  on public.calendar_events for update
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN create policy "Psychologists can delete own events"
  on public.calendar_events for delete
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create table if not exists public.calendar_event_series_exceptions (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.calendar_event_series(id) on delete cascade,
  
  
  original_date date not null,
  
  
  exception_type public.series_exception_type not null,
  
  
  new_start_datetime timestamptz,
  new_end_datetime timestamptz,
  
  
  modified_fields jsonb,
  
  
  reason text,
  
  
  created_at timestamptz not null default now(),
  
  constraint unique_series_exception unique (series_id, original_date)
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_series_exceptions_series on public.calendar_event_series_exceptions(series_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_series_exceptions_date on public.calendar_event_series_exceptions(original_date); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series_exceptions' AND schemaname = 'public') THEN alter table public.calendar_event_series_exceptions enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series_exceptions' AND schemaname = 'public') THEN create policy "Psychologists can manage exceptions via series"
  on public.calendar_event_series_exceptions for all
  using (
    exists (
      select 1 from public.calendar_event_series s
      where s.id = series_id and s.psychologist_id = auth.uid()
    )
  ); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create table if not exists public.clinical_session_details (
  id uuid primary key default gen_random_uuid(),
  calendar_event_id uuid not null references public.calendar_events(id) on delete cascade,
  
  
  psychologist_client_id uuid references public.psychologist_clients(id) on delete set null,
  psychologist_service_id uuid references public.psychologist_services(id) on delete set null,
  patient_id uuid not null references public.patients(id) on delete cascade,
  session_type_id uuid references public.session_types(id) on delete set null,
  session_number integer,
  
  
  clinical_session_id uuid references public.clinical_sessions(id) on delete set null,
  
  
  attendance_confirmed boolean default false,
  confirmation_sent_at timestamptz,
  reminder_sent_at timestamptz,
  
  
  billing_status text, 
  
  
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  
  constraint unique_event_session unique (calendar_event_id)
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_session_details_event on public.clinical_session_details(calendar_event_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_session_details_patient on public.clinical_session_details(patient_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_session_details_clinical on public.clinical_session_details(clinical_session_id) where clinical_session_id is not null; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_session_details' AND schemaname = 'public') THEN alter table public.clinical_session_details enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'details' AND schemaname = 'public') THEN create policy "Psychologists can manage session details via event"
  on public.clinical_session_details for all
  using (
    exists (
      select 1 from public.calendar_events e
      where e.id = calendar_event_id and e.psychologist_id = auth.uid()
    )
  ); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create table if not exists public.google_sync_logs (
  id uuid primary key default gen_random_uuid(),
  psychologist_id uuid not null references public.psychologists(id) on delete cascade,
  
  
  calendar_event_id uuid references public.calendar_events(id) on delete set null,
  series_id uuid references public.calendar_event_series(id) on delete set null,
  google_event_id text,
  
  
  sync_direction public.sync_direction not null,
  operation public.sync_operation not null,
  status public.sync_result_status not null,
  
  
  request_payload jsonb,
  response_payload jsonb,
  error_message text,
  error_code text,
  
  
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  
  
  created_at timestamptz not null default now()
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_sync_logs_psychologist on public.google_sync_logs(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_sync_logs_event on public.google_sync_logs(calendar_event_id) where calendar_event_id is not null; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_sync_logs_status on public.google_sync_logs(status); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_sync_logs_created on public.google_sync_logs(created_at); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_logs' AND schemaname = 'public') THEN alter table public.google_sync_logs enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_logs' AND schemaname = 'public') THEN create policy "Psychologists can view own sync logs"
  on public.google_sync_logs for select
  using (psychologist_id = auth.uid()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_logs' AND schemaname = 'public') THEN create policy "Service role can insert sync logs"
  on public.google_sync_logs for insert
  with check (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DROP VIEW IF EXISTS public.calendar_events_full CASCADE;
CREATE OR REPLACE VIEW public.calendar_events_full AS
SELECT 
    e.*,
    sd.psychologist_client_id,
    sd.psychologist_service_id,
    sd.session_number,
    sd.clinical_session_id,
    sd.attendance_confirmed,
    sd.billing_status,
    COALESCE(pc.manual_full_name, pc.synced_full_name) as patient_name,
    COALESCE(pc.manual_display_name, pc.synced_display_name) as patient_display_name,
    ps.name as service_name,
    ps.price as service_price,
    ps.duration_minutes as service_duration
FROM public.calendar_events e
LEFT JOIN public.clinical_session_details sd ON sd.calendar_event_id = e.id
LEFT JOIN public.psychologist_clients pc ON pc.id = sd.psychologist_client_id
LEFT JOIN public.psychologist_services ps ON ps.id = sd.psychologist_service_id;
create or replace function public.get_calendar_events(
  p_psychologist_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz,
  p_event_types calendar_event_type[] default null
)
returns setof public.calendar_events_full
language sql
stable
security definer
as $$
  select *
  from public.calendar_events_full
  where psychologist_id = p_psychologist_id
    and start_datetime >= p_start_date
    and start_datetime < p_end_date
    and (p_event_types is null or event_type = any(p_event_types))
  order by start_datetime;
$$;
create or replace function public.check_calendar_conflicts(
  p_psychologist_id uuid,
  p_start_datetime timestamptz,
  p_end_datetime timestamptz,
  p_exclude_event_id uuid default null
)
returns table(
  event_id uuid,
  event_type calendar_event_type,
  title text,
  start_datetime timestamptz,
  end_datetime timestamptz
)
language sql
stable
security definer
as $$
  select id, event_type, title, start_datetime, end_datetime
  from public.calendar_events
  where psychologist_id = p_psychologist_id
    and status not in ('cancelled', 'rescheduled')
    and (p_exclude_event_id is null or id != p_exclude_event_id)
    and start_datetime < p_end_datetime
    and end_datetime > p_start_datetime;
$$;
create or replace function public.update_calendar_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN create trigger trg_calendar_events_updated_at
  before update on public.calendar_events
  for each row execute function public.update_calendar_updated_at(); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series' AND schemaname = 'public') THEN create trigger trg_calendar_event_series_updated_at
  before update on public.calendar_event_series
  for each row execute function public.update_calendar_updated_at(); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_session_details' AND schemaname = 'public') THEN create trigger trg_clinical_session_details_updated_at
  before update on public.clinical_session_details
  for each row execute function public.update_calendar_updated_at(); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_calendar_connections' AND schemaname = 'public') THEN create trigger trg_google_calendar_connections_updated_at
  before update on public.google_calendar_connections
  for each row execute function public.update_calendar_updated_at(); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
drop view if exists public.calendar_events_full cascade;
DROP VIEW IF EXISTS public.calendar_events_full CASCADE;
CREATE OR REPLACE VIEW public.calendar_events_full AS
SELECT 
    e.*,
    sd.psychologist_client_id,
    sd.psychologist_service_id,
    sd.session_number,
    sd.clinical_session_id,
    sd.attendance_confirmed,
    sd.billing_status,
    COALESCE(pc.manual_full_name, pc.synced_full_name) as patient_name,
    COALESCE(pc.manual_display_name, pc.synced_display_name) as patient_display_name,
    ps.name as service_name,
    ps.price as service_price,
    ps.duration_minutes as service_duration
FROM public.calendar_events e
LEFT JOIN public.clinical_session_details sd ON sd.calendar_event_id = e.id
LEFT JOIN public.psychologist_clients pc ON pc.id = sd.psychologist_client_id
LEFT JOIN public.psychologist_services ps ON ps.id = sd.psychologist_service_id;
create extension if not exists "pgcrypto";
create or replace function encrypt_token_base64(token text, encryption_key text)
returns text
language sql
stable
as $$
  select encode(extensions.pgp_sym_encrypt(token, encryption_key), 'base64');
$$;
create or replace function decrypt_token_base64(encrypted_token_base64 text, encryption_key text)
returns text
language sql
stable
as $$
  select extensions.pgp_sym_decrypt(decode(encrypted_token_base64, 'base64'), encryption_key)::text;
$$;
alter table google_calendar_connections
  add column if not exists access_token_encrypted bytea,
  add column if not exists refresh_token_encrypted bytea,
  add column if not exists sync_token text,
  add column if not exists last_full_sync_at timestamptz,
  add column if not exists last_incremental_sync_at timestamptz,
  add column if not exists consecutive_errors integer not null default 0;
alter table google_calendar_connections
  alter column access_token drop not null,
  alter column refresh_token drop not null;
ALTER TABLE google_calendar_connections
  DROP COLUMN IF EXISTS access_token_encrypted,
  DROP COLUMN IF EXISTS refresh_token_encrypted;
ALTER TABLE google_calendar_connections
  ADD COLUMN IF NOT EXISTS access_token_encrypted text,
  ADD COLUMN IF NOT EXISTS refresh_token_encrypted text;
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.unschedule('renew-google-watch-channels')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'renew-google-watch-channels'
);
SELECT cron.unschedule('process-google-sync-queue')
WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'process-google-sync-queue'
);
ALTER TABLE "public"."calendar_events"
  DROP CONSTRAINT IF EXISTS "calendar_events_series_id_fkey";
ALTER TABLE "public"."calendar_events"
  ADD CONSTRAINT "calendar_events_series_id_fkey"
    FOREIGN KEY ("series_id")
    REFERENCES "public"."calendar_event_series"("id")
    ON DELETE CASCADE;
CREATE TABLE IF NOT EXISTS "sync_conflict_resolutions" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    "psychologist_id" uuid NOT NULL REFERENCES "auth"."users"("id") ON DELETE CASCADE,
    "event_id" uuid REFERENCES "calendar_events"("id") ON DELETE SET NULL,
    "google_event_id" text,
    "title" text,
    "message" text,
    "conflict_type" text NOT NULL CHECK (conflict_type IN ('update', 'delete')),
    "fluri_data" jsonb,
    "google_data" jsonb,
    "status" text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved')),
    "resolution" text CHECK (resolution IN ('kept_fluri', 'took_google', 'manual')),
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "resolved_at" timestamp with time zone
);
ALTER TABLE "sync_conflict_resolutions" ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN CREATE POLICY "Users can view their own conflicts"
    ON "sync_conflict_resolutions"
    FOR SELECT
    USING (auth.uid() = psychologist_id); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN CREATE POLICY "Users can update their own conflicts"
    ON "sync_conflict_resolutions"
    FOR UPDATE
    USING (auth.uid() = psychologist_id); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS "idx_calendar_events_series_start"
    ON "calendar_events" ("series_id", "start_datetime")
    WHERE series_id IS NOT NULL; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
CREATE OR REPLACE VIEW "view_sync_health_stats" AS
SELECT 
    ce.psychologist_id,
    p.full_name as psychologist_name,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'synced') as synced_count,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'error') as error_count,
    MAX(ce.last_synced_at) as last_sync_activity,
    gcc.sync_sessions,
    gcc.updated_at as connection_updated_at
FROM calendar_events ce
JOIN psychologists p ON ce.psychologist_id = p.id
LEFT JOIN google_calendar_connections gcc ON ce.psychologist_id = gcc.psychologist_id
GROUP BY ce.psychologist_id, p.full_name, gcc.sync_sessions, gcc.updated_at;
CREATE OR REPLACE VIEW "view_sync_backlog" AS
SELECT 
    count(*) as total_backlog,
    count(*) FILTER (WHERE updated_at < now() - interval '1 hour') as stuck_events_1h
FROM calendar_events 
WHERE google_sync_status = 'pending';
CREATE OR REPLACE FUNCTION public.create_session_with_calendar(
  p_psychologist_id UUID,
  p_patient_id UUID,
  p_start_time TIMESTAMPTZ,
  p_duration_minutes INTEGER DEFAULT 50,
  p_service_id UUID DEFAULT NULL,
  p_location_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_custom_price_cents INTEGER DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_recurrence_rule TEXT DEFAULT NULL,
  p_timezone TEXT DEFAULT 'America/Sao_Paulo',
  p_session_type_id UUID DEFAULT NULL,
  p_session_number INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_session_id UUID;
  v_event_id UUID;
  v_note_id UUID;
  v_details_id UUID;
  v_patient_record RECORD;
  v_service_record RECORD;
  v_negotiated_price INTEGER;
  v_effective_price INTEGER;
  v_snapshot_service_name TEXT;
  v_catalog_service_id UUID;
  v_session_status TEXT;
  v_calendar_status TEXT;
  v_end_time TIMESTAMPTZ;
  v_patient_name TEXT;
  v_event_title TEXT;
  v_empty_note_content TEXT;
BEGIN
  
  
  
  
  
  IF p_psychologist_id IS NULL THEN
    RAISE EXCEPTION 'psychologist_id is required';
  END IF;
  
  IF p_patient_id IS NULL THEN
    RAISE EXCEPTION 'patient_id (psychologist_client_id) is required';
  END IF;
  
  IF p_start_time IS NULL THEN
    RAISE EXCEPTION 'start_time is required';
  END IF;
  
  
  IF p_duration_minutes < 15 OR p_duration_minutes > 240 THEN
    RAISE EXCEPTION 'duration_minutes must be between 15 and 240';
  END IF;
  
  
  
  
  
  SELECT 
    id,
    default_session_price,
    manual_full_name,
    synced_full_name
  INTO v_patient_record
  FROM public.psychologist_clients
  WHERE id = p_patient_id 
    AND psychologist_id = p_psychologist_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Patient not found or does not belong to psychologist';
  END IF;
  
  
  
  
  
  v_effective_price := NULL;
  v_snapshot_service_name := NULL;
  v_catalog_service_id := NULL;
  
  
  IF p_service_id IS NOT NULL THEN
    SELECT 
      ps.price,
      ps.service_id,
      psc.name
    INTO v_service_record
    FROM public.psychologist_services ps
    LEFT JOIN public.psychological_services_catalog psc ON psc.id = ps.service_id
    WHERE ps.id = p_service_id 
      AND ps.psychologist_id = p_psychologist_id;
    
    IF FOUND THEN
      v_effective_price := v_service_record.price;
      v_catalog_service_id := v_service_record.service_id;
      v_snapshot_service_name := v_service_record.name;
      
      
      IF v_catalog_service_id IS NOT NULL THEN
        SELECT price_cents
        INTO v_negotiated_price
        FROM public.psychologist_client_services
        WHERE psychologist_id = p_psychologist_id
          AND psychologist_client_id = p_patient_id
          AND service_id = v_catalog_service_id;
        
        IF FOUND THEN
          v_effective_price := v_negotiated_price;
        END IF;
      END IF;
    END IF;
  END IF;
  
  
  IF v_effective_price IS NULL AND v_patient_record.default_session_price IS NOT NULL THEN
    v_effective_price := v_patient_record.default_session_price;
  END IF;
  
  
  IF p_custom_price_cents IS NOT NULL THEN
    v_effective_price := p_custom_price_cents;
  END IF;
  
  
  
  
  
  IF p_status IS NOT NULL THEN
    v_session_status := p_status;
  ELSE
    
    IF p_start_time < NOW() THEN
      v_session_status := 'open';
    ELSE
      v_session_status := 'scheduled';
    END IF;
  END IF;
  
  
  CASE v_session_status
    WHEN 'cancelled' THEN v_calendar_status := 'cancelled';
    WHEN 'no_show' THEN v_calendar_status := 'no_show';
    WHEN 'completed' THEN v_calendar_status := 'completed';
    ELSE v_calendar_status := 'scheduled';
  END CASE;
  
  
  
  
  
  v_end_time := p_start_time + (p_duration_minutes || ' minutes')::INTERVAL;
  
  
  
  
  
  v_patient_name := COALESCE(
    v_patient_record.manual_full_name,
    v_patient_record.synced_full_name,
    'Paciente'
  );
  v_event_title := 'Sessão - ' || v_patient_name;
  
  
  
  
  
  v_empty_note_content := encode(
    convert_to(
      '{"root":{"children":[{"children":[],"direction":null,"format":"","indent":0,"type":"paragraph","version":1,"textFormat":0,"textStyle":""}],"direction":null,"format":"","indent":0,"type":"root","version":1}}',
      'UTF8'
    ),
    'base64'
  );
  
  
  
  
  
  INSERT INTO public.clinical_sessions (
    psychologist_id,
    psychologist_client_id,
    start_time,
    duration_minutes,
    psychologist_service_id,
    location_id,
    snapshot_service_name,
    snapshot_price,
    custom_price_cents,
    notes,
    recurrence_rule,
    session_timezone,
    status,
    created_by,
    created_at,
    updated_at
  ) VALUES (
    p_psychologist_id,
    p_patient_id,
    p_start_time,
    p_duration_minutes,
    p_service_id,
    p_location_id,
    v_snapshot_service_name,
    v_effective_price,
    p_custom_price_cents,
    p_notes,
    p_recurrence_rule,
    p_timezone,
    v_session_status,
    p_psychologist_id,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_session_id;
  
  
  
  
  
  INSERT INTO public.calendar_events (
    psychologist_id,
    event_type,
    title,
    description,
    start_datetime,
    end_datetime,
    duration_minutes,
    timezone,
    all_day,
    status,
    source,
    google_sync_status,
    private_notes,
    metadata,
    created_at,
    updated_at
  ) VALUES (
    p_psychologist_id,
    'session',
    v_event_title,
    p_notes,
    p_start_time,
    v_end_time,
    p_duration_minutes,
    p_timezone,
    FALSE,
    v_calendar_status,
    'fluri',
    'pending',
    NULL,
    jsonb_build_object(
      'patient_id', p_patient_id,
      'clinical_session_id', v_session_id,
      'session_type_id', p_session_type_id,
      'service_id', p_service_id,
      'location_id', p_location_id,
      'price', v_effective_price,
      'session_number', p_session_number
    ),
    NOW(),
    NOW()
  )
  RETURNING id INTO v_event_id;
  
  
  
  
  
  INSERT INTO public.clinical_session_details (
    calendar_event_id,
    patient_id,
    clinical_session_id,
    session_type_id,
    psychologist_service_id,
    session_number,
    billing_status,
    attendance_confirmed,
    created_at,
    updated_at
  ) VALUES (
    v_event_id,
    p_patient_id,
    v_session_id,
    p_session_type_id,
    p_service_id,
    p_session_number,
    'pending',
    FALSE,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_details_id;
  
  
  
  
  
  INSERT INTO public.clinical_notes (
    psychologist_id,
    patient_id,
    session_id,
    note_type,
    encoded_content,
    title,
    is_archived,
    created_by,
    created_at,
    updated_at
  ) VALUES (
    p_psychologist_id,
    p_patient_id,
    v_session_id,
    'clinical_note',
    v_empty_note_content,
    'Nota da Sessão',
    FALSE,
    p_psychologist_id,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_note_id;
  
  
  
  
  
  UPDATE public.clinical_sessions
  SET note_id = v_note_id,
      updated_at = NOW()
  WHERE id = v_session_id;
  
  
  
  
  
  RETURN jsonb_build_object(
    'session_id', v_session_id,
    'event_id', v_event_id,
    'note_id', v_note_id,
    'details_id', v_details_id,
    'status', v_session_status,
    'effective_price', v_effective_price
  );
  
EXCEPTION
  WHEN OTHERS THEN
    
    RAISE EXCEPTION 'Failed to create session: %', SQLERRM;
END;
$$;
CREATE OR REPLACE FUNCTION enqueue_event_for_google_sync()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  
  IF NEW.source = 'fluri' AND NEW.google_sync_status = 'pending' THEN
    INSERT INTO sync_queue (
      psychologist_id,
      type,
      status,
      event_id,
      event_data,
      created_at,
      updated_at
    ) VALUES (
      NEW.psychologist_id,
      'fluri_to_google',
      'pending',
      NEW.id,
      jsonb_build_object(
        'event_id', NEW.id,
        'action', 'create'
      ),
      now(),
      now()
    );
    
    RAISE LOG 'Enqueued event % for Google Calendar sync', NEW.id;
  END IF;

  RETURN NEW;
END;
$$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN DROP TRIGGER IF EXISTS trigger_enqueue_google_sync ON calendar_events; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN CREATE TRIGGER trigger_enqueue_google_sync
  AFTER INSERT ON calendar_events
  FOR EACH ROW
  EXECUTE FUNCTION enqueue_event_for_google_sync(); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
CREATE OR REPLACE FUNCTION public.get_weekly_availability_config(
  p_psychologist_id uuid
)
RETURNS TABLE (
  day_of_week integer,
  intervals jsonb,
  is_active boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pa.day_of_week,
    jsonb_agg(
      jsonb_build_object(
        'id', pa.id,
        'startTime', pa.start_time::text,
        'endTime', pa.end_time::text,
        'locationId', pa.location_id,
        'deliveryMode', pa.delivery_mode,
        'availableForFirstAppointment', pa.available_for_first_appointment,
        'dailyAppointmentLimit', pa.daily_appointment_limit
      ) ORDER BY pa.start_time
    ) as intervals,
    bool_or(pa.is_active) as is_active
  FROM public.psychologist_availability pa
  WHERE pa.psychologist_id = p_psychologist_id
    AND pa.is_active = true
    AND (pa.effective_start IS NULL OR pa.effective_start <= CURRENT_DATE)
    AND (pa.effective_end IS NULL OR pa.effective_end >= CURRENT_DATE)
  GROUP BY pa.day_of_week
  ORDER BY pa.day_of_week;
END;
$$;
CREATE OR REPLACE FUNCTION public.upsert_weekly_availability(
  p_psychologist_id uuid,
  p_day_of_week integer,
  p_is_active boolean,
  p_intervals jsonb DEFAULT '[]'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_interval jsonb;
  v_start_time time;
  v_end_time time;
  v_location_id uuid;
  v_delivery_mode public.delivery_mode;
  v_available_for_first boolean;
BEGIN
  
  IF p_day_of_week < 0 OR p_day_of_week > 6 THEN
    RAISE EXCEPTION 'Invalid day_of_week: must be between 0 and 6';
  END IF;
  
  
  IF (SELECT auth.uid()) != p_psychologist_id THEN
    RAISE EXCEPTION 'Unauthorized: can only modify own availability';
  END IF;
  
  
  UPDATE public.psychologist_availability
  SET 
    is_active = false,
    updated_at = now()
  WHERE psychologist_id = p_psychologist_id
    AND day_of_week = p_day_of_week;
  
  
  IF p_is_active THEN
    FOR v_interval IN SELECT * FROM jsonb_array_elements(p_intervals)
    LOOP
      
      v_start_time := (v_interval->>'startTime')::time;
      v_end_time := (v_interval->>'endTime')::time;
      v_location_id := (v_interval->>'locationId')::uuid;
      v_delivery_mode := COALESCE(
        (v_interval->>'deliveryMode')::public.delivery_mode,
        'hybrid'::public.delivery_mode
      );
      v_available_for_first := COALESCE(
        (v_interval->>'availableForFirstAppointment')::boolean,
        true
      );
      
      
      IF v_end_time <= v_start_time THEN
        RAISE EXCEPTION 'Invalid time range: end_time must be after start_time';
      END IF;
      
      
      INSERT INTO public.psychologist_availability (
        psychologist_id,
        day_of_week,
        start_time,
        end_time,
        location_id,
        delivery_mode,
        available_for_first_appointment,
        is_active,
        effective_start,
        effective_end,
        daily_appointment_limit
      )
      VALUES (
        p_psychologist_id,
        p_day_of_week,
        v_start_time,
        v_end_time,
        v_location_id,
        v_delivery_mode,
        v_available_for_first,
        true,
        NULL,
        NULL,
        (v_interval->>'dailyAppointmentLimit')::integer
      )
      ON CONFLICT (psychologist_id, day_of_week, start_time) 
      DO UPDATE SET
        end_time = EXCLUDED.end_time,
        location_id = EXCLUDED.location_id,
        delivery_mode = EXCLUDED.delivery_mode,
        available_for_first_appointment = EXCLUDED.available_for_first_appointment,
        is_active = EXCLUDED.is_active,
        daily_appointment_limit = EXCLUDED.daily_appointment_limit,
        updated_at = now();
    END LOOP;
  END IF;
END;
$$;
CREATE OR REPLACE FUNCTION public.get_upcoming_exceptions(
  p_psychologist_id uuid,
  p_from_date date DEFAULT CURRENT_DATE,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  exception_date date,
  is_available boolean,
  start_time time,
  end_time time,
  reason text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ae.id,
    ae.exception_date,
    ae.is_available,
    ae.start_time,
    ae.end_time,
    ae.reason,
    ae.created_at
  FROM public.availability_exceptions ae
  WHERE ae.psychologist_id = p_psychologist_id
    AND ae.exception_date >= p_from_date
  ORDER BY ae.exception_date, ae.start_time NULLS FIRST
  LIMIT p_limit;
END;
$$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_psychologist_availability_active_day
  ON public.psychologist_availability(psychologist_id, day_of_week, is_active)
  WHERE is_active = true; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_availability_exceptions_future
  ON public.availability_exceptions(psychologist_id, exception_date)
  WHERE exception_date >= CURRENT_DATE; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create table if not exists public.google_sync_idempotency (
  idempotency_key text primary key,
  psychologist_id uuid not null references public.psychologists(id) on delete cascade,
  calendar_event_id uuid references public.calendar_events(id) on delete set null,
  operation text not null check (operation in ('create','update','delete','sync')),
  status text not null check (status in ('processing','completed','failed')),
  request_data jsonb,
  response_data jsonb,
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  completed_at timestamptz,
  expires_at timestamptz not null
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_google_sync_idempotency_psychologist_id on public.google_sync_idempotency(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_google_sync_idempotency_calendar_event_id on public.google_sync_idempotency(calendar_event_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_google_sync_idempotency_status on public.google_sync_idempotency(status); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_google_sync_idempotency_expires_at on public.google_sync_idempotency(expires_at); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_idempotency' AND schemaname = 'public') THEN alter table public.google_sync_idempotency enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_idempotency' AND schemaname = 'public') THEN create policy "google_sync_idempotency_select_own"
  on public.google_sync_idempotency for select
  to authenticated
  using ((select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_idempotency' AND schemaname = 'public') THEN create policy "google_sync_idempotency_insert_own"
  on public.google_sync_idempotency for insert
  to authenticated
  with check ((select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_idempotency' AND schemaname = 'public') THEN create policy "google_sync_idempotency_update_own"
  on public.google_sync_idempotency for update
  to authenticated
  using ((select auth.uid()) = psychologist_id)
  with check ((select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create or replace function public.cleanup_expired_idempotency_keys()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.google_sync_idempotency
  where expires_at < now();
end;
$$;
create table if not exists public.google_sync_queue (
  id uuid primary key default gen_random_uuid(),
  psychologist_id uuid not null references public.psychologists(id) on delete cascade,
  action text not null,
  status text not null default 'pending' check (status in ('pending','processing','completed','failed')),
  payload jsonb,
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  completed_at timestamptz
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_google_sync_queue_psychologist_id on public.google_sync_queue(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_google_sync_queue_status on public.google_sync_queue(status); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_queue' AND schemaname = 'public') THEN alter table public.google_sync_queue enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_queue' AND schemaname = 'public') THEN create policy "google_sync_queue_select_own"
  on public.google_sync_queue for select
  to authenticated
  using ((select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_queue' AND schemaname = 'public') THEN create policy "google_sync_queue_insert_own"
  on public.google_sync_queue for insert
  to authenticated
  with check ((select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_queue' AND schemaname = 'public') THEN create policy "google_sync_queue_update_own"
  on public.google_sync_queue for update
  to authenticated
  using ((select auth.uid()) = psychologist_id)
  with check ((select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create table if not exists public.weekly_availability_configs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  day_of_week int not null check (day_of_week >= 0 and day_of_week <= 6),
  is_active boolean default false,
  intervals jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, day_of_week)
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'if' AND schemaname = 'public') THEN create index if not exists idx_weekly_availability_user_id on public.weekly_availability_configs(user_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'weekly_availability_configs' AND schemaname = 'public') THEN alter table public.weekly_availability_configs enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'weekly_availability_configs' AND schemaname = 'public') THEN create policy "weekly_availability_select_own"
  on public.weekly_availability_configs for select
  to authenticated
  using ((select auth.uid()) = user_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'weekly_availability_configs' AND schemaname = 'public') THEN create policy "weekly_availability_insert_own"
  on public.weekly_availability_configs for insert
  to authenticated
  with check ((select auth.uid()) = user_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'weekly_availability_configs' AND schemaname = 'public') THEN create policy "weekly_availability_update_own"
  on public.weekly_availability_configs for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create table if not exists public.sync_locks (
  lock_key text primary key,
  locked_at timestamptz not null default now(),
  expires_at timestamptz not null,
  locked_by text
);
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_locks' AND schemaname = 'public') THEN alter table public.sync_locks enable row level security; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
create or replace function public.acquire_sync_lock(
  p_lock_key text,
  p_ttl_ms integer default 60000,
  p_locked_by text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_expires timestamptz := v_now + make_interval(secs => (p_ttl_ms / 1000.0));
begin
  
  insert into public.sync_locks (lock_key, locked_at, expires_at, locked_by)
  values (p_lock_key, v_now, v_expires, p_locked_by)
  on conflict (lock_key) do nothing;

  
  if found then
    return true;
  end if;

  
  update public.sync_locks
    set locked_at = v_now,
        expires_at = v_expires,
        locked_by = p_locked_by
  where lock_key = p_lock_key
    and expires_at <= v_now;

  return found;
end;
$$;
create or replace function public.release_sync_lock(
  p_lock_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.sync_locks where lock_key = p_lock_key;
end;
$$;
create or replace function public.check_sync_lock(
  p_lock_key text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1 from public.sync_locks
    where lock_key = p_lock_key
      and expires_at > now()
  );
end;
$$;
create or replace function public.cleanup_expired_sync_locks()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.sync_locks where expires_at <= now();
end;
$$;
BEGIN;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_clients' AND schemaname = 'public') THEN ALTER TABLE public.psychologist_clients ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_subscriptions' AND schemaname = 'public') THEN ALTER TABLE public.psychologist_subscriptions ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'financial_categories' AND schemaname = 'public') THEN ALTER TABLE public.financial_categories ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'medications_catalog' AND schemaname = 'public') THEN ALTER TABLE public.medications_catalog ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'medication_dosages' AND schemaname = 'public') THEN ALTER TABLE public.medication_dosages ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'medication_terms' AND schemaname = 'public') THEN ALTER TABLE public.medication_terms ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychological_disorders_catalog' AND schemaname = 'public') THEN ALTER TABLE public.psychological_disorders_catalog ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'session_cancellation_policies_catalog' AND schemaname = 'public') THEN ALTER TABLE public.session_cancellation_policies_catalog ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_activities_catalog' AND schemaname = 'public') THEN ALTER TABLE public.clinical_activities_catalog ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_deletion_audit_log' AND schemaname = 'public') THEN ALTER TABLE public.patient_deletion_audit_log ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_session_details' AND schemaname = 'public') THEN ALTER TABLE public.clinical_session_details ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN ALTER TABLE public.psychologist_locations ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_sessions' AND schemaname = 'public') THEN ALTER TABLE public.clinical_sessions ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_session_cancellation_policy' AND schemaname = 'public') THEN ALTER TABLE public.psychologist_session_cancellation_policy ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'session_reschedule_logs' AND schemaname = 'public') THEN ALTER TABLE public.session_reschedule_logs ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'session_reschedule_requests' AND schemaname = 'public') THEN ALTER TABLE public.session_reschedule_requests ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_client_charges' AND schemaname = 'public') THEN ALTER TABLE public.psychologist_client_charges ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_notes' AND schemaname = 'public') THEN ALTER TABLE public.clinical_notes ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_tests' AND schemaname = 'public') THEN ALTER TABLE public.patient_tests ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'document_templates' AND schemaname = 'public') THEN ALTER TABLE public.document_templates ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'generated_documents' AND schemaname = 'public') THEN ALTER TABLE public.generated_documents ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'interview_templates' AND schemaname = 'public') THEN ALTER TABLE public.interview_templates ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_financial_entries' AND schemaname = 'public') THEN ALTER TABLE public.psychologist_financial_entries ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_activity_assignments' AND schemaname = 'public') THEN ALTER TABLE public.patient_activity_assignments ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_activity_responses' AND schemaname = 'public') THEN ALTER TABLE public.patient_activity_responses ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'recurring_transactions' AND schemaname = 'public') THEN ALTER TABLE public.recurring_transactions ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'transaction_attachments' AND schemaname = 'public') THEN ALTER TABLE public.transaction_attachments ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'audit_logs' AND schemaname = 'public') THEN ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'global_tags' AND schemaname = 'public') THEN ALTER TABLE public.global_tags ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'webhook_events' AND schemaname = 'public') THEN ALTER TABLE public.webhook_events ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'webhook_failures' AND schemaname = 'public') THEN ALTER TABLE public.webhook_failures ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'financial_transaction_categories' AND schemaname = 'public') THEN ALTER TABLE public.financial_transaction_categories ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_preferences' AND schemaname = 'public') THEN ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_preferences_audit_log' AND schemaname = 'public') THEN ALTER TABLE public.user_preferences_audit_log ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_availability' AND schemaname = 'public') THEN ALTER TABLE public.psychologist_availability ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'availability_exceptions' AND schemaname = 'public') THEN ALTER TABLE public.availability_exceptions ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'linktree_links' AND schemaname = 'public') THEN ALTER TABLE public.linktree_links ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_calendar_connections' AND schemaname = 'public') THEN ALTER TABLE public.google_calendar_connections ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series' AND schemaname = 'public') THEN ALTER TABLE public.calendar_event_series ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series_exceptions' AND schemaname = 'public') THEN ALTER TABLE public.calendar_event_series_exceptions ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_logs' AND schemaname = 'public') THEN ALTER TABLE public.google_sync_logs ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_queue' AND schemaname = 'public') THEN ALTER TABLE public.sync_queue ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_notifications' AND schemaname = 'public') THEN ALTER TABLE public.sync_notifications ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_conflict_resolutions' AND schemaname = 'public') THEN ALTER TABLE public.sync_conflict_resolutions ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_idempotency' AND schemaname = 'public') THEN ALTER TABLE public.google_sync_idempotency ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_queue' AND schemaname = 'public') THEN ALTER TABLE public.google_sync_queue ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'weekly_availability_configs' AND schemaname = 'public') THEN ALTER TABLE public.weekly_availability_configs ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_locks' AND schemaname = 'public') THEN ALTER TABLE public.sync_locks ENABLE ROW LEVEL SECURITY; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
ALTER FUNCTION public.auto_update_past_session_status() SET search_path = public;
ALTER FUNCTION public.enforce_linktree_active_limit() SET search_path = public;
ALTER FUNCTION public.get_weekly_availability_config(uuid) SET search_path = public;
ALTER FUNCTION public.upsert_weekly_availability(uuid, integer, boolean, jsonb) SET search_path = public;
ALTER FUNCTION public.handle_new_session_charge() SET search_path = public;
ALTER FUNCTION public.handle_session_update_charge() SET search_path = public;
ALTER FUNCTION public.consolidate_existing_paid_charges() SET search_path = public;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'admins' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "admins_select_admin" ON public.admins; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'admins' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "admins_select_own" ON public.admins; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'admins' AND schemaname = 'public') THEN CREATE POLICY "admins_select" ON public.admins 
FOR SELECT TO authenticated 
USING (is_admin() OR (select auth.uid()) = id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'assistants' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "assistants_select_admin" ON public.assistants; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'assistants' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "assistants_select_own" ON public.assistants; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'assistants' AND schemaname = 'public') THEN CREATE POLICY "assistants_select" ON public.assistants 
FOR SELECT TO authenticated 
USING (is_admin() OR (select auth.uid()) = id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patients' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "patients_select_admin_v2" ON public.patients; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patients' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "patients_select_own_v2" ON public.patients; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patients' AND schemaname = 'public') THEN CREATE POLICY "patients_select" ON public.patients 
FOR SELECT TO authenticated 
USING (is_admin() OR (select auth.uid()) = id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DROP VIEW IF EXISTS public.view_sync_health_stats;
CREATE VIEW public.view_sync_health_stats AS
SELECT 
    ce.psychologist_id,
    p.full_name as psychologist_name,
    COUNT(*) as total_events,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'synced') as synced_count,
    COUNT(*) FILTER (WHERE ce.google_sync_status = 'error') as error_count,
    MAX(ce.last_synced_at) as last_sync_activity
FROM public.calendar_events ce
JOIN public.psychologists p ON ce.psychologist_id = p.id
GROUP BY ce.psychologist_id, p.full_name;
DROP INDEX IF EXISTS public.idx_user_roles_user_id_fixed;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_availability_exceptions_psych_id ON public.availability_exceptions(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_calendar_event_series_psych_id ON public.calendar_event_series(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_calendar_events_series_id ON public.calendar_events(series_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_clinical_notes_created_by ON public.clinical_notes(created_by); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_clinical_session_details_session_id ON public.clinical_session_details(clinical_session_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_clinical_sessions_created_by ON public.clinical_sessions(created_by); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_clinical_sessions_default_charge_id ON public.clinical_sessions(default_charge_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_financial_categories_psych_id ON public.financial_categories(psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_google_sync_logs_series_id ON public.google_sync_logs(series_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_activity_assignments_act_id ON public.patient_activity_assignments(activity_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_patient_tests_note_id ON public.patient_tests(clinical_note_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_transaction_attachments_charge_id ON public.transaction_attachments(charge_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
COMMIT;
BEGIN;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'audit_logs' AND schemaname = 'public') THEN CREATE POLICY "audit_logs_owner_access" ON public.audit_logs
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = user_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'availability_exceptions' AND schemaname = 'public') THEN CREATE POLICY "availability_exceptions_owner_access" ON public.availability_exceptions
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series' AND schemaname = 'public') THEN CREATE POLICY "calendar_event_series_owner_access" ON public.calendar_event_series
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_events' AND schemaname = 'public') THEN CREATE POLICY "calendar_events_owner_access" ON public.calendar_events
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_notes' AND schemaname = 'public') THEN CREATE POLICY "clinical_notes_owner_access" ON public.clinical_notes
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_sessions' AND schemaname = 'public') THEN CREATE POLICY "clinical_sessions_owner_access" ON public.clinical_sessions
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'financial_categories' AND schemaname = 'public') THEN CREATE POLICY "financial_categories_owner_access" ON public.financial_categories
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'generated_documents' AND schemaname = 'public') THEN CREATE POLICY "generated_documents_owner_access" ON public.generated_documents
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'global_tags' AND schemaname = 'public') THEN CREATE POLICY "global_tags_owner_access" ON public.global_tags
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_calendar_connections' AND schemaname = 'public') THEN CREATE POLICY "google_calendar_connections_owner_access" ON public.google_calendar_connections
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_idempotency' AND schemaname = 'public') THEN CREATE POLICY "google_sync_idempotency_owner_access" ON public.google_sync_idempotency
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_logs' AND schemaname = 'public') THEN CREATE POLICY "google_sync_logs_owner_access" ON public.google_sync_logs
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'google_sync_queue' AND schemaname = 'public') THEN CREATE POLICY "google_sync_queue_owner_access" ON public.google_sync_queue
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'linktree_links' AND schemaname = 'public') THEN CREATE POLICY "linktree_links_owner_access" ON public.linktree_links
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_activity_assignments' AND schemaname = 'public') THEN CREATE POLICY "patient_activity_assignments_owner_access" ON public.patient_activity_assignments
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_tests' AND schemaname = 'public') THEN CREATE POLICY "patient_tests_owner_access" ON public.patient_tests
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_availability' AND schemaname = 'public') THEN CREATE POLICY "psychologist_availability_owner_access" ON public.psychologist_availability
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_client_charges' AND schemaname = 'public') THEN CREATE POLICY "psychologist_client_charges_owner_access" ON public.psychologist_client_charges
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_financial_entries' AND schemaname = 'public') THEN CREATE POLICY "psychologist_financial_entries_owner_access" ON public.psychologist_financial_entries
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN CREATE POLICY "psychologist_locations_owner_access" ON public.psychologist_locations
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_session_cancellation_policy' AND schemaname = 'public') THEN CREATE POLICY "psychologist_session_cancellation_policy_owner_access" ON public.psychologist_session_cancellation_policy
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'recurring_transactions' AND schemaname = 'public') THEN CREATE POLICY "recurring_transactions_owner_access" ON public.recurring_transactions
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_conflict_resolutions' AND schemaname = 'public') THEN CREATE POLICY "sync_conflict_resolutions_owner_access" ON public.sync_conflict_resolutions
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_notifications' AND schemaname = 'public') THEN CREATE POLICY "sync_notifications_owner_access" ON public.sync_notifications
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_queue' AND schemaname = 'public') THEN CREATE POLICY "sync_queue_owner_access" ON public.sync_queue
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_preferences' AND schemaname = 'public') THEN CREATE POLICY "user_preferences_owner_access" ON public.user_preferences
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = user_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_preferences_audit_log' AND schemaname = 'public') THEN CREATE POLICY "user_preferences_audit_log_owner_access" ON public.user_preferences_audit_log
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = user_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'weekly_availability_configs' AND schemaname = 'public') THEN CREATE POLICY "weekly_availability_configs_owner_access" ON public.weekly_availability_configs
FOR ALL TO authenticated USING (is_admin() OR (select auth.uid()) = user_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_activities_catalog' AND schemaname = 'public') THEN CREATE POLICY "clinical_activities_catalog_read" ON public.clinical_activities_catalog
FOR SELECT TO authenticated USING (active = true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'document_templates' AND schemaname = 'public') THEN CREATE POLICY "document_templates_read" ON public.document_templates
FOR SELECT TO authenticated USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'financial_transaction_categories' AND schemaname = 'public') THEN CREATE POLICY "financial_transaction_categories_read" ON public.financial_transaction_categories
FOR SELECT TO authenticated USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'interview_templates' AND schemaname = 'public') THEN CREATE POLICY "interview_templates_read" ON public.interview_templates
FOR SELECT TO authenticated USING (is_public = true OR (select auth.uid()) = created_by); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'medication_dosages' AND schemaname = 'public') THEN CREATE POLICY "medication_dosages_read" ON public.medication_dosages
FOR SELECT TO authenticated USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'medication_terms' AND schemaname = 'public') THEN CREATE POLICY "medication_terms_read" ON public.medication_terms
FOR SELECT TO authenticated USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'medications_catalog' AND schemaname = 'public') THEN CREATE POLICY "medications_catalog_read" ON public.medications_catalog
FOR SELECT TO authenticated USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychological_disorders_catalog' AND schemaname = 'public') THEN CREATE POLICY "psychological_disorders_catalog_read" ON public.psychological_disorders_catalog
FOR SELECT TO authenticated USING (true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'session_cancellation_policies_catalog' AND schemaname = 'public') THEN CREATE POLICY "session_cancellation_policies_catalog_read" ON public.session_cancellation_policies_catalog
FOR SELECT TO authenticated USING (active = true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'calendar_event_series_exceptions' AND schemaname = 'public') THEN CREATE POLICY "series_exceptions_owner_access" ON public.calendar_event_series_exceptions
FOR ALL TO authenticated USING (
  is_admin() OR EXISTS (
    SELECT 1 FROM public.calendar_event_series s 
    WHERE s.id = series_id AND s.psychologist_id = (select auth.uid())
  )
); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_session_details' AND schemaname = 'public') THEN CREATE POLICY "session_details_owner_access" ON public.clinical_session_details
FOR ALL TO authenticated USING (
  is_admin() OR EXISTS (
    SELECT 1 FROM public.clinical_sessions s 
    WHERE s.id = clinical_session_id AND s.psychologist_id = (select auth.uid())
  )
); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_activity_responses' AND schemaname = 'public') THEN CREATE POLICY "activity_responses_owner_access" ON public.patient_activity_responses
FOR ALL TO authenticated USING (
  is_admin() OR EXISTS (
    SELECT 1 FROM public.patient_activity_assignments a 
    WHERE a.id = assignment_id AND a.psychologist_id = (select auth.uid())
  )
); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'session_reschedule_logs' AND schemaname = 'public') THEN CREATE POLICY "reschedule_logs_owner_access" ON public.session_reschedule_logs
FOR ALL TO authenticated USING (
  is_admin() OR EXISTS (
    SELECT 1 FROM public.clinical_sessions s 
    WHERE s.id = session_id AND s.psychologist_id = (select auth.uid())
  )
); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'session_reschedule_requests' AND schemaname = 'public') THEN CREATE POLICY "reschedule_requests_owner_access" ON public.session_reschedule_requests
FOR ALL TO authenticated USING (
  is_admin() OR EXISTS (
    SELECT 1 FROM public.clinical_sessions s 
    WHERE s.id = session_id AND s.psychologist_id = (select auth.uid())
  )
); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'transaction_attachments' AND schemaname = 'public') THEN CREATE POLICY "transaction_attachments_owner_access" ON public.transaction_attachments
FOR ALL TO authenticated USING (
  is_admin() OR EXISTS (
    SELECT 1 FROM public.psychologist_financial_entries e 
    WHERE e.id = financial_entry_id AND e.psychologist_id = (select auth.uid())
  ) OR EXISTS (
    SELECT 1 FROM public.psychologist_client_charges c 
    WHERE c.id = charge_id AND c.psychologist_id = (select auth.uid())
  )
); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'patient_deletion_audit_log' AND schemaname = 'public') THEN CREATE POLICY "patient_deletion_audit_log_admin" ON public.patient_deletion_audit_log
FOR SELECT TO authenticated USING (is_admin()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'sync_locks' AND schemaname = 'public') THEN CREATE POLICY "sync_locks_admin" ON public.sync_locks
FOR SELECT TO authenticated USING (is_admin()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'webhook_events' AND schemaname = 'public') THEN CREATE POLICY "webhook_events_admin" ON public.webhook_events
FOR SELECT TO authenticated USING (is_admin()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'webhook_failures' AND schemaname = 'public') THEN CREATE POLICY "webhook_failures_admin" ON public.webhook_failures
FOR SELECT TO authenticated USING (is_admin()); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
COMMIT;
BEGIN;
UPDATE public.psychologist_services
SET is_active = true
WHERE is_active IS NULL;
ALTER TABLE public.psychologist_services
  ALTER COLUMN is_active SET NOT NULL,
  ALTER COLUMN is_active SET DEFAULT true;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_services' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "psychologist_services_select_own" ON public.psychologist_services; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_services' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "psychologist_services_select_public_or_own" ON public.psychologist_services; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_services' AND schemaname = 'public') THEN CREATE POLICY "psychologist_services_select_authenticated"
  ON public.psychologist_services
  FOR SELECT
  TO authenticated
  USING (
    
    (SELECT auth.uid()) = psychologist_id
    OR
    
    (
      is_active = true
      AND EXISTS (
        SELECT 1 FROM public.psychologist_profiles pp
        WHERE pp.id = psychologist_services.psychologist_id
        AND pp.is_public = true
      )
    )
  ); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_services' AND schemaname = 'public') THEN CREATE POLICY "psychologist_services_select_anon"
  ON public.psychologist_services
  FOR SELECT
  TO anon
  USING (
    is_active = true
    AND EXISTS (
      SELECT 1 FROM public.psychologist_profiles pp
      WHERE pp.id = psychologist_services.psychologist_id
      AND pp.is_public = true
    )
  ); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_services' AND schemaname = 'public') THEN CREATE POLICY "psychologist_services_insert_own"
  ON public.psychologist_services
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_services' AND schemaname = 'public') THEN CREATE POLICY "psychologist_services_update_own"
  ON public.psychologist_services
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = psychologist_id)
  WITH CHECK ((SELECT auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_services' AND schemaname = 'public') THEN CREATE POLICY "psychologist_services_delete_own"
  ON public.psychologist_services
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_psychologist_services_active
  ON public.psychologist_services(psychologist_id, is_active)
  WHERE is_active = true; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
UPDATE public.psychologist_locations
SET is_active = true
WHERE is_active IS NULL;
ALTER TABLE public.psychologist_locations
  ALTER COLUMN is_active SET NOT NULL,
  ALTER COLUMN is_active SET DEFAULT true;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "psychologist_locations_select_own" ON public.psychologist_locations; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN CREATE POLICY "psychologist_locations_select_own"
  ON public.psychologist_locations
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = psychologist_id AND is_active = true); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "psychologist_locations_insert_own" ON public.psychologist_locations; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN CREATE POLICY "psychologist_locations_insert_own"
  ON public.psychologist_locations
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "psychologist_locations_update_own" ON public.psychologist_locations; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN CREATE POLICY "psychologist_locations_update_own"
  ON public.psychologist_locations
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = psychologist_id)
  WITH CHECK ((SELECT auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN DROP POLICY IF EXISTS "psychologist_locations_delete_own" ON public.psychologist_locations; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_locations' AND schemaname = 'public') THEN CREATE POLICY "psychologist_locations_delete_own"
  ON public.psychologist_locations
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = psychologist_id); END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'IF' AND schemaname = 'public') THEN CREATE INDEX IF NOT EXISTS idx_psychologist_locations_active
  ON public.psychologist_locations(psychologist_id, is_active)
  WHERE is_active = true; END IF; EXCEPTION WHEN OTHERS THEN NULL; END $$;
COMMIT;
grant select on public.calendar_events_full to authenticated;
grant select on public.calendar_events_full to anon;
GRANT EXECUTE ON FUNCTION public.create_session_with_calendar TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_weekly_availability_config(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_weekly_availability(uuid, integer, boolean, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_upcoming_exceptions(uuid, date, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_weekly_availability_overlaps(uuid, integer, jsonb) TO authenticated;
GRANT SELECT ON public.view_sync_health_stats TO authenticated;
