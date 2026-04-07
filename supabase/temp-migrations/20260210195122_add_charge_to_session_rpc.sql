-- Add charge creation to create_session_with_calendar RPC
-- This ensures atomicity: Session + Calendar Event + Charge are created together
-- Charge date is set to Session Start Time
create or replace function public.create_session_with_calendar(
  p_psychologist_id uuid,
  p_patient_id uuid,
  p_start_time timestamp with time zone,
  p_duration_minutes integer default 50,
  p_service_id uuid default null,
  p_location_id uuid default null,
  p_notes text default null,
  p_custom_price_cents integer default null,
  p_status text default null,
  p_recurrence_rule text default null,
  p_timezone text default 'America/Sao_Paulo',
  p_session_type_id uuid default null,
  p_session_number integer default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session_id uuid;
  v_event_id uuid;
  v_note_id uuid;
  v_details_id uuid;
  v_charge_id uuid;
  v_patient_record record;
  v_service_record record;
  v_negotiated_price integer;
  v_effective_price integer;
  v_snapshot_service_name text;
  v_session_status public.clinical_session_status;
  v_calendar_status public.calendar_event_status;
  v_end_time timestamptz;
  v_patient_name text;
  v_event_title text;
  v_empty_note_content text;
begin
  if p_psychologist_id is null then
    raise exception 'psychologist_id is required';
  end if;

  if p_patient_id is null then
    raise exception 'patient_id (psychologist_client_id) is required';
  end if;

  if p_start_time is null then
    raise exception 'start_time is required';
  end if;

  if p_duration_minutes < 15 or p_duration_minutes > 240 then
    raise exception 'duration_minutes must be between 15 and 240';
  end if;

  select
    id,
    default_session_price,
    manual_full_name,
    synced_full_name
  into v_patient_record
  from public.psychologist_clients
  where id = p_patient_id
    and psychologist_id = p_psychologist_id;

  if not found then
    raise exception 'Patient not found or does not belong to psychologist';
  end if;

  v_effective_price := null;
  v_snapshot_service_name := null;

  -- service_id refers to psychologist_services.id
  if p_service_id is not null then
    select
      ps.price,
      ps.name as service_name,
      psc.name as catalog_name
    into v_service_record
    from public.psychologist_services ps
    left join public.psychological_services_catalog psc on psc.id = ps.catalog_id
    where ps.id = p_service_id
      and ps.psychologist_id = p_psychologist_id;

    if found then
      v_effective_price := v_service_record.price;
      v_snapshot_service_name := coalesce(v_service_record.catalog_name, v_service_record.service_name);

      -- negotiated price is stored per psychologist_services.id
      select price_cents
      into v_negotiated_price
      from public.psychologist_client_services
      where psychologist_id = p_psychologist_id
        and psychologist_client_id = p_patient_id
        and service_id = p_service_id;

      if found then
        v_effective_price := v_negotiated_price;
      end if;
    end if;
  end if;

  if v_effective_price is null and v_patient_record.default_session_price is not null then
    v_effective_price := v_patient_record.default_session_price;
  end if;

  if p_custom_price_cents is not null then
    v_effective_price := p_custom_price_cents;
  end if;

  if p_status is not null then
    v_session_status := p_status::public.clinical_session_status;
  else
    if p_start_time < now() then
      v_session_status := 'open'::public.clinical_session_status;
    else
      v_session_status := 'scheduled'::public.clinical_session_status;
    end if;
  end if;

  case v_session_status
    when 'cancelled' then v_calendar_status := 'cancelled'::public.calendar_event_status;
    when 'no_show' then v_calendar_status := 'no_show'::public.calendar_event_status;
    when 'completed' then v_calendar_status := 'completed'::public.calendar_event_status;
    else v_calendar_status := 'scheduled'::public.calendar_event_status;
  end case;

  v_end_time := p_start_time + (p_duration_minutes || ' minutes')::interval;

  v_patient_name := coalesce(
    v_patient_record.manual_full_name,
    v_patient_record.synced_full_name,
    'Paciente'
  );
  v_event_title := 'Sessao - ' || v_patient_name;

  v_empty_note_content := encode(
    convert_to(
      '{"root":{"children":[{"children":[],"direction":null,"format":"","indent":0,"type":"paragraph","version":1,"textFormat":0,"textStyle":""}],"direction":null,"format":"","indent":0,"type":"root","version":1}}',
      'UTF8'
    ),
    'base64'
  );

  -- 1. Create the session
  insert into public.clinical_sessions (
    psychologist_id,
    psychologist_client_id,
    start_time,
    duration_minutes,
    psychologist_service_id,
    location_id,
    snapshot_service_name,
    snapshot_price_cents,
    notes,
    status,
    created_by,
    created_at,
    updated_at
  ) values (
    p_psychologist_id,
    p_patient_id,
    p_start_time,
    p_duration_minutes,
    p_service_id,
    p_location_id,
    v_snapshot_service_name,
    v_effective_price,
    p_notes,
    v_session_status,
    p_psychologist_id,
    now(),
    now()
  )
  returning id into v_session_id;

  -- 2. Create the calendar event
  insert into public.calendar_events (
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
  ) values (
    p_psychologist_id,
    'session',
    v_event_title,
    p_notes,
    p_start_time,
    v_end_time,
    p_duration_minutes,
    p_timezone,
    false,
    v_calendar_status,
    'fluri',
    'pending',
    null,
    jsonb_build_object(
      'patient_id', p_patient_id,
      'clinical_session_id', v_session_id,
      'session_type_id', p_session_type_id,
      'service_id', p_service_id,
      'location_id', p_location_id,
      'price', v_effective_price,
      'session_number', p_session_number,
      'recurrence_rule', p_recurrence_rule
    ),
    now(),
    now()
  )
  returning id into v_event_id;

  -- 3. Create session details
  insert into public.clinical_session_details (
    calendar_event_id,
    psychologist_client_id,
    clinical_session_id,
    session_type_id,
    psychologist_service_id,
    session_number,
    billing_status,
    attendance_confirmed,
    created_at,
    updated_at
  ) values (
    v_event_id,
    p_patient_id,
    v_session_id,
    p_session_type_id,
    p_service_id,
    p_session_number,
    'pending',
    false,
    now(),
    now()
  )
  returning id into v_details_id;

  -- 4. Create clinical note
  insert into public.clinical_notes (
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
  ) values (
    p_psychologist_id,
    p_patient_id,
    v_session_id,
    'clinical_note',
    v_empty_note_content,
    'Nota da Sessao',
    false,
    p_psychologist_id,
    now(),
    now()
  )
  returning id into v_note_id;

  -- 5. Create charge if price > 0
  v_charge_id := null;
  if v_effective_price is not null and v_effective_price > 0 then
    insert into public.psychologist_client_charges (
      psychologist_id,
      psychologist_client_id,
      session_id,
      service_id,
      price_cents,
      payment_status,
      created_by,
      created_at, -- Use session start time as creation date!
      updated_at
    ) values (
      p_psychologist_id,
      p_patient_id,
      v_session_id,
      p_service_id,
      v_effective_price,
      'pending',
      p_psychologist_id,
      p_start_time, -- CRITICAL: Use session start time
      now()
    )
    returning id into v_charge_id;
  end if;

  -- 6. Update session with note and charge (if created)
  update public.clinical_sessions
  set note_id = v_note_id,
      default_charge_id = v_charge_id, -- Link the charge!
      updated_at = now()
  where id = v_session_id;

  return jsonb_build_object(
    'session_id', v_session_id,
    'event_id', v_event_id,
    'note_id', v_note_id,
    'details_id', v_details_id,
    'charge_id', v_charge_id,
    'status', v_session_status::text,
    'effective_price', v_effective_price
  );
exception
  when others then
    raise exception 'Failed to create session: %', sqlerrm;
end;
$$;
