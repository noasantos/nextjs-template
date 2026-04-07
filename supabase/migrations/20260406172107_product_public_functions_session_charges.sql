-- migration-created-via: pnpm supabase:migration:new
-- created-at-utc: 2026-04-06T17:21:07Z

SET check_function_bodies = false;

--
-- Name: create_session_charge_if_due(uuid, uuid, integer, boolean, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_session_charge_if_due(p_session_id uuid, p_psychologist_id uuid, p_lead_days integer DEFAULT 7, p_force boolean DEFAULT false, p_idempotency_key text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
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
