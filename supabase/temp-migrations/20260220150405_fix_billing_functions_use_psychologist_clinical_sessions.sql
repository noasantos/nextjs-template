-- migration-created-via: pnpm supabase:migration:new
-- Purpose: Fix process_pending_session_billing and create_session_charge_if_due to use
--   psychologist_clinical_sessions (renamed from clinical_sessions in 20260217095717)
--   and psychologist_patient_charges / psychologist_patient_id (renamed in 20260217200722).
-- Fixes RPC error: relation "public.clinical_sessions" does not exist (42P01).

-------------------------------------------------------------------------------
-- 1. create_session_charge_if_due: use psychologist_clinical_sessions and patient naming
-------------------------------------------------------------------------------
create or replace function public.create_session_charge_if_due(
  p_session_id uuid,
  p_psychologist_id uuid,
  p_lead_days integer default 7,
  p_force boolean default false,
  p_idempotency_key text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session record;
  v_charge_id uuid;
  v_due_date date;
  v_charge_created_at timestamptz;
  v_timezone text;
  v_next_attempt_at timestamptz;
  v_eligible_now boolean;
begin
  if p_session_id is null then
    raise exception 'session_id is required';
  end if;

  if p_psychologist_id is null then
    raise exception 'psychologist_id is required';
  end if;

  if p_lead_days < 0 then
    raise exception 'lead_days must be >= 0';
  end if;

  select
    cs.id,
    cs.psychologist_id,
    cs.psychologist_patient_id,
    cs.start_time,
    cs.status,
    cs.snapshot_price_cents,
    cs.snapshot_service_name,
    cs.default_charge_id,
    coalesce(ce.timezone, 'America/Sao_Paulo') as timezone
  into v_session
  from public.psychologist_clinical_sessions cs
  left join public.clinical_session_details sd
    on sd.clinical_session_id = cs.id
  left join public.calendar_events ce
    on ce.id = sd.calendar_event_id
  where cs.id = p_session_id
    and cs.psychologist_id = p_psychologist_id
  limit 1;

  if not found then
    raise exception 'Session not found or does not belong to psychologist';
  end if;

  if v_session.status in ('cancelled', 'no_show') then
    update public.psychologist_patient_charges
    set
      payment_status = 'cancelled',
      updated_at = now(),
      updated_by = p_psychologist_id
    where session_id = p_session_id
      and payment_status = 'pending';

    update public.clinical_session_details
    set
      billing_status = 'canceled',
      billing_next_attempt_at = null,
      billing_last_error = null,
      updated_at = now()
    where clinical_session_id = p_session_id;

    return jsonb_build_object(
      'session_id', p_session_id,
      'charge_id', null,
      'eligible_now', false,
      'created', false,
      'reason', 'session_not_billable'
    );
  end if;

  if coalesce(v_session.snapshot_price_cents, 0) <= 0 then
    update public.clinical_session_details
    set
      billing_status = 'canceled',
      billing_next_attempt_at = null,
      billing_last_error = null,
      updated_at = now()
    where clinical_session_id = p_session_id;

    delete from public.psychologist_patient_charges
    where session_id = p_session_id
      and payment_status = 'pending';

    return jsonb_build_object(
      'session_id', p_session_id,
      'charge_id', null,
      'eligible_now', false,
      'created', false,
      'reason', 'non_billable_session'
    );
  end if;

  v_eligible_now := p_force or v_session.start_time <= (now() + make_interval(days => p_lead_days));

  if not v_eligible_now then
    v_next_attempt_at := greatest(now(), v_session.start_time - make_interval(days => p_lead_days));
    v_timezone := coalesce(nullif(v_session.timezone, ''), 'America/Sao_Paulo');
    v_due_date := (v_session.start_time at time zone v_timezone)::date;

    update public.psychologist_patient_charges
    set
      due_date = v_due_date,
      description = coalesce(v_session.snapshot_service_name, public.psychologist_patient_charges.description),
      updated_at = now(),
      updated_by = p_psychologist_id
    where session_id = p_session_id
      and payment_status = 'pending';

    update public.clinical_session_details
    set
      billing_status = 'pending_window',
      billing_next_attempt_at = v_next_attempt_at,
      billing_last_error = null,
      updated_at = now()
    where clinical_session_id = p_session_id;

    return jsonb_build_object(
      'session_id', p_session_id,
      'charge_id', null,
      'eligible_now', false,
      'created', false,
      'reason', 'outside_lead_window',
      'next_attempt_at', v_next_attempt_at
    );
  end if;

  v_timezone := coalesce(nullif(v_session.timezone, ''), 'America/Sao_Paulo');
  v_due_date := (v_session.start_time at time zone v_timezone)::date;
  v_charge_created_at := ((v_due_date::text || ' 12:00:00+00')::timestamptz);

  insert into public.psychologist_patient_charges (
    psychologist_id,
    psychologist_patient_id,
    session_id,
    price_cents,
    due_date,
    payment_status,
    description,
    created_by,
    updated_by,
    created_at,
    updated_at
  ) values (
    v_session.psychologist_id,
    v_session.psychologist_patient_id,
    p_session_id,
    v_session.snapshot_price_cents,
    v_due_date,
    'pending',
    coalesce(v_session.snapshot_service_name, 'Sessão de Terapia'),
    p_psychologist_id,
    p_psychologist_id,
    v_charge_created_at,
    now()
  )
  on conflict (session_id) where session_id is not null
  do update set
    psychologist_patient_id = excluded.psychologist_patient_id,
    price_cents = excluded.price_cents,
    due_date = excluded.due_date,
    description = excluded.description,
    updated_at = now(),
    updated_by = p_psychologist_id,
    payment_status = case
      when public.psychologist_patient_charges.payment_status = 'paid' then public.psychologist_patient_charges.payment_status
      else 'pending'
    end
  returning id into v_charge_id;

  perform set_config('app.fluri.skip_charge_triggers', 'on', true);

  update public.psychologist_clinical_sessions
  set
    default_charge_id = v_charge_id,
    updated_at = now(),
    updated_by = coalesce(updated_by, p_psychologist_id)
  where id = p_session_id;

  update public.clinical_session_details
  set
    billing_status = 'charged',
    billing_attempt_count = coalesce(billing_attempt_count, 0) + 1,
    billing_last_attempt_at = now(),
    billing_next_attempt_at = null,
    billing_last_error = null,
    updated_at = now()
  where clinical_session_id = p_session_id;

  return jsonb_build_object(
    'session_id', p_session_id,
    'charge_id', v_charge_id,
    'eligible_now', true,
    'created', true,
    'reason', 'charged_now',
    'idempotency_key', coalesce(p_idempotency_key, format('charge:session:%s:v1', p_session_id))
  );
exception
  when others then
    update public.clinical_session_details
    set
      billing_status = 'charge_failed',
      billing_attempt_count = coalesce(billing_attempt_count, 0) + 1,
      billing_last_attempt_at = now(),
      billing_next_attempt_at = now() + interval '1 hour',
      billing_last_error = left(sqlerrm, 500),
      updated_at = now()
    where clinical_session_id = p_session_id;

    insert into public.session_billing_dead_letter (
      session_id,
      psychologist_id,
      error_message,
      context,
      attempts,
      updated_at
    ) values (
      p_session_id,
      p_psychologist_id,
      left(sqlerrm, 500),
      jsonb_build_object(
        'lead_days', p_lead_days,
        'forced', p_force,
        'idempotency_key', p_idempotency_key,
        'timestamp', now()
      ),
      1,
      now()
    )
    on conflict (session_id) where resolved_at is null
    do update set
      error_message = excluded.error_message,
      context = public.session_billing_dead_letter.context || excluded.context,
      attempts = public.session_billing_dead_letter.attempts + 1,
      updated_at = now();

    return jsonb_build_object(
      'session_id', p_session_id,
      'charge_id', null,
      'eligible_now', false,
      'created', false,
      'reason', 'error',
      'error', sqlerrm
    );
end;
$$;
-------------------------------------------------------------------------------
-- 2. process_pending_session_billing (2-arg): use psychologist_clinical_sessions
-------------------------------------------------------------------------------
create or replace function public.process_pending_session_billing(
  p_limit integer default 200,
  p_lead_days integer default 7
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate record;
  v_result jsonb;
  v_processed integer := 0;
  v_charged integer := 0;
  v_failed integer := 0;
  v_skipped integer := 0;
begin
  for v_candidate in
    with candidates as (
      select
        cs.id as session_id,
        cs.psychologist_id
      from public.clinical_session_details sd
      join public.psychologist_clinical_sessions cs
        on cs.id = sd.clinical_session_id
      where sd.clinical_session_id is not null
        and sd.billing_status in ('pending', 'pending_window', 'ready_to_charge', 'charge_failed')
        and cs.status not in ('cancelled', 'no_show')
        and coalesce(cs.snapshot_price_cents, 0) > 0
        and cs.start_time <= (now() + make_interval(days => p_lead_days))
        and (sd.billing_next_attempt_at is null or sd.billing_next_attempt_at <= now())
      order by cs.start_time asc
      limit p_limit
      for update of sd skip locked
    )
    select * from candidates
  loop
    v_processed := v_processed + 1;

    v_result := public.create_session_charge_if_due(
      v_candidate.session_id,
      v_candidate.psychologist_id,
      p_lead_days,
      false,
      format('charge:session:%s:v1', v_candidate.session_id)
    );

    if coalesce(v_result ->> 'reason', '') = 'error' then
      v_failed := v_failed + 1;
    elsif nullif(v_result ->> 'charge_id', '') is not null then
      v_charged := v_charged + 1;
    else
      v_skipped := v_skipped + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'processed', v_processed,
    'charged', v_charged,
    'failed', v_failed,
    'skipped', v_skipped,
    'lead_days', p_lead_days,
    'limit', p_limit,
    'processed_at', now()
  );
end;
$$;
