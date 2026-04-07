-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-02-20T16:51:50Z

-- Align remaining patient invite / charge columns with remote production contract.
alter table if exists public.psychologist_patients
  add column if not exists invite_token text;
create unique index if not exists psychologist_patients_invite_token_key
  on public.psychologist_patients(invite_token)
  where invite_token is not null;
alter table if exists public.psychologist_patient_charges
  add column if not exists payment_notes text,
  add column if not exists invoice_number text,
  add column if not exists invoice_url text,
  add column if not exists document_status text,
  add column if not exists last_sent_at timestamp with time zone,
  add column if not exists sent_count integer default 0;
