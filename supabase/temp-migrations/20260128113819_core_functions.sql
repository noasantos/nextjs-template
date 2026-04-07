CREATE EXTENSION IF NOT EXISTS pgcrypto;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  claims jsonb;
  user_role public.app_role;
BEGIN
  
  SELECT role INTO user_role FROM public.user_roles WHERE user_id = (event->>'user_id')::uuid;

  claims := event->'claims';

  IF user_role IS NOT NULL THEN
    
    claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
  ELSE
    claims := jsonb_set(claims, '{user_role}', 'null');
  END IF;

  
  event := jsonb_set(event, '{claims}', claims);

  
  RETURN event;
END;
$$;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  sub_status text;
  p_user_id uuid;
  p_avatar_url text;
  p_user_metadata jsonb;
  p_provider text;
  p_google_picture text;
  p_is_google_default_photo boolean;
begin
  
  p_user_id := (event->>'user_id')::uuid;
  
  
  claims := coalesce(event->'claims', '{}'::jsonb);

  
  
  p_user_metadata := coalesce(event->'raw_user_meta_data', '{}'::jsonb);
  p_google_picture := coalesce(p_user_metadata->>'picture', p_user_metadata->>'avatar_url', '');
  
  
  
  p_provider := null;
  
  
  if event->'identities' is not null and jsonb_array_length(event->'identities') > 0 then
    p_provider := event->'identities'->0->>'provider';
  end if;
  
  
  
  if p_provider is null and p_google_picture != '' and p_google_picture like '%googleusercontent.com%' then
    p_provider := 'google';
  end if;

  
  begin
    
    select role into user_role 
    from public.user_roles 
    where user_id = p_user_id;

    
    if user_role is not null then
      claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
    else
      claims := jsonb_set(claims, '{user_role}', 'null');
    end if;

    
    if user_role = 'psychologist' then
      select onboarding_completed, subscription_status, avatar_url
      into onboarding_status, sub_status, p_avatar_url
      from public.psychologists
      where id = p_user_id;
      
      
      claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
      
      
      claims := jsonb_set(claims, '{subscription_status}', to_jsonb(coalesce(sub_status, 'none')));
      
      
      
      
      
      
      if p_avatar_url is not null and p_avatar_url != '' then
        
        claims := jsonb_set(claims, '{avatar_url}', to_jsonb(p_avatar_url));
        claims := jsonb_set(claims, '{avatar_source}', '"custom"');
        claims := jsonb_set(claims, '{is_default_photo}', 'false');
      elsif p_provider = 'google' and p_google_picture != '' then
        
        
        
        p_is_google_default_photo := (
          p_google_picture like '%googleusercontent.com%' and
          (p_google_picture like '%=s96-c%' or 
           p_google_picture like '%=s128-c%' or 
           p_google_picture like '%photo.jpg%')
        );
        
        claims := jsonb_set(claims, '{avatar_url}', to_jsonb(p_google_picture));
        claims := jsonb_set(claims, '{avatar_source}', '"google"');
        claims := jsonb_set(claims, '{is_default_photo}', to_jsonb(p_is_google_default_photo));
      else
        
        claims := jsonb_set(claims, '{avatar_url}', 'null');
        claims := jsonb_set(claims, '{avatar_source}', '"none"');
        claims := jsonb_set(claims, '{is_default_photo}', 'false');
      end if;
      
      
      if p_provider is not null then
        claims := jsonb_set(claims, '{auth_provider}', to_jsonb(p_provider));
      end if;
    else
      
      claims := jsonb_set(claims, '{onboarding_completed}', 'true');
      
      claims := jsonb_set(claims, '{subscription_status}', '"none"');
      
      claims := jsonb_set(claims, '{avatar_url}', 'null');
      claims := jsonb_set(claims, '{avatar_source}', '"none"');
      claims := jsonb_set(claims, '{is_default_photo}', 'false');
    end if;

  exception when others then
    
    
    claims := jsonb_set(claims, '{user_role}', 'null');
    claims := jsonb_set(claims, '{onboarding_completed}', 'false');
    claims := jsonb_set(claims, '{subscription_status}', '"none"');
    claims := jsonb_set(claims, '{avatar_url}', 'null');
    claims := jsonb_set(claims, '{avatar_source}', '"none"');
    claims := jsonb_set(claims, '{is_default_photo}', 'false');
  end;

  
  event := jsonb_set(event, '{claims}', claims);

  
  return event;
end;
$$;
DROP FUNCTION IF EXISTS public.get_user_id_by_email(text) CASCADE;
CREATE OR REPLACE FUNCTION public.get_user_id_by_email(p_email text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  target_id uuid;
BEGIN
  SELECT id INTO target_id FROM auth.users WHERE email = p_email LIMIT 1;
  RETURN target_id;
END;
$$;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  p_user_id uuid;
begin
  
  p_user_id := (event->>'user_id')::uuid;
  
  
  select role into user_role 
  from public.user_roles 
  where user_id = p_user_id;

  claims := event->'claims';

  
  if user_role is not null then
    claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
  else
    claims := jsonb_set(claims, '{user_role}', 'null');
  end if;

  
  if user_role = 'psychologist' then
    select onboarding_completed into onboarding_status
    from public.psychologists
    where id = p_user_id;
    
    
    claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
  else
    
    claims := jsonb_set(claims, '{onboarding_completed}', 'true');
  end if;

  
  event := jsonb_set(event, '{claims}', claims);

  
  return event;
end;
$$;
DROP FUNCTION IF EXISTS public.complete_psychologist_onboarding() CASCADE;
create or replace function public.complete_psychologist_onboarding()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_user_id uuid;
  p_role public.app_role;
begin
  
  p_user_id := auth.uid();
  
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  if p_role != 'psychologist' then
    raise exception 'Only psychologists can complete onboarding';
  end if;
  
  
  update public.psychologists
  set 
    onboarding_completed = true,
    updated_at = now()
  where id = p_user_id;
  
  
  return true;
end;
$$;
DROP FUNCTION IF EXISTS public.get_onboarding_status() CASCADE;
create or replace function public.get_onboarding_status()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_user_id uuid;
  p_role public.app_role;
  p_status boolean;
begin
  
  p_user_id := auth.uid();
  
  if p_user_id is null then
    return false;
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return true;
  end if;
  
  
  select onboarding_completed into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, false);
end;
$$;
DROP FUNCTION IF EXISTS public.handle_new_psychologist() CASCADE;
create or replace function public.handle_new_psychologist()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  
  if new.role = 'psychologist' then
    
    insert into public.psychologists (id)
    values (new.user_id)
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.update_psychologist_clients_updated_at() CASCADE;
create or replace function public.update_psychologist_clients_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.update_clinical_sessions_updated_at() CASCADE;
create or replace function public.update_clinical_sessions_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.empty_lexical_state_base64() CASCADE;
create or replace function public.empty_lexical_state_base64()
returns text
language sql
immutable
as $$
  select encode('{"root":{"children":[{"children":[],"direction":null,"format":"","indent":0,"type":"paragraph","version":1}],"direction":null,"format":"","indent":0,"type":"root","version":1}}'::bytea, 'base64');
$$;
DROP FUNCTION IF EXISTS public.text_to_lexical_base64(text) CASCADE;
create or replace function public.text_to_lexical_base64(input_text text)
returns text
language sql
immutable
as $$
  select encode(
    format(
      '{"root":{"children":[{"children":[{"detail":0,"format":0,"mode":"normal","style":"","text":"%s","type":"text","version":1}],"direction":"ltr","format":"","indent":0,"type":"paragraph","version":1}],"direction":"ltr","format":"","indent":0,"type":"root","version":1}}',
      replace(replace(replace(input_text, '\', '\\'), '"', '\"'), E'\n', '\n')
    )::bytea,
    'base64'
  );
$$;
DROP FUNCTION IF EXISTS public.is_webhook_event_processed(text) CASCADE;
create or replace function public.is_webhook_event_processed(p_event_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.webhook_events
    where event_id = p_event_id
  );
$$;
DROP FUNCTION IF EXISTS public.update_psychologist_subscriptions_trigger() CASCADE;
create or replace function public.update_psychologist_subscriptions_trigger()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  
  new.has_active_subscription = (
    new.status in ('active', 'trialing') and 
    (new.current_period_end is null or new.current_period_end > now())
  );
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.check_subscription_access(uuid) CASCADE;
create or replace function public.check_subscription_access(p_therapist_id uuid)
returns table (
  status text,
  has_access boolean,
  trial_end timestamptz,
  current_period_end timestamptz,
  days_remaining integer,
  is_in_grace_period boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_sub record;
  v_grace_period interval := interval '3 days';
begin
  select * into v_sub
  from public.psychologist_subscriptions
  where psychologist_id = p_therapist_id;
  
  if not found then
    return query select 
      'inactive'::text,
      false,
      null::timestamptz,
      null::timestamptz,
      0,
      false;
    return;
  end if;
  
  return query select
    v_sub.status,
    v_sub.has_active_subscription or 
      (v_sub.current_period_end is not null and v_sub.current_period_end + v_grace_period > now()),
    v_sub.trial_ends_at,
    v_sub.current_period_end,
    case 
      when v_sub.current_period_end is null then 0
      else greatest(0, extract(day from v_sub.current_period_end - now()))::integer
    end,
    v_sub.current_period_end is not null and 
      v_sub.current_period_end < now() and 
      v_sub.current_period_end + v_grace_period > now();
end;
$$;
DROP FUNCTION IF EXISTS public.broadcast_subscription_update(uuid) CASCADE;
create or replace function public.broadcast_subscription_update(p_therapist_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  
  
  perform pg_notify(
    'subscription_updated',
    json_build_object('psychologist_id', p_therapist_id)::text
  );
end;
$$;
DROP FUNCTION IF EXISTS public.get_user_role(uuid) CASCADE;
create or replace function public.get_user_role(p_user_id uuid)
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.user_roles
  where user_id = p_user_id
  limit 1;
$$;
DROP FUNCTION IF EXISTS public.current_user_role() CASCADE;
create or replace function public.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.user_roles
  where user_id = (select auth.uid())
  limit 1;
$$;
DROP FUNCTION IF EXISTS public.user_has_role(uuid, public.app_role) CASCADE;
create or replace function public.user_has_role(p_user_id uuid, p_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = p_user_id
      and role = p_role
  );
$$;
DROP FUNCTION IF EXISTS public.is_psychologist() CASCADE;
create or replace function public.is_psychologist()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'psychologist'
  );
$$;
DROP FUNCTION IF EXISTS public.is_patient() CASCADE;
create or replace function public.is_patient()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'patient'
  );
$$;
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'admin'
  );
$$;
DROP FUNCTION IF EXISTS public.is_assistant() CASCADE;
create or replace function public.is_assistant()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'assistant'
  );
$$;
DROP FUNCTION IF EXISTS public.is_own_psychologist_data(uuid) CASCADE;
create or replace function public.is_own_psychologist_data(p_psychologist_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_psychologist_id = (select auth.uid());
$$;
DROP FUNCTION IF EXISTS public.is_own_patient_data(uuid) CASCADE;
create or replace function public.is_own_patient_data(p_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_patient_id = (select auth.uid());
$$;
DROP FUNCTION IF EXISTS public.has_client_access(uuid) CASCADE;
create or replace function public.has_client_access(p_psychologist_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.psychologist_clients
    where id = p_psychologist_client_id
      and psychologist_id = (select auth.uid())
  );
$$;
DROP FUNCTION IF EXISTS public.is_linked_to_psychologist_client(uuid) CASCADE;
create or replace function public.is_linked_to_psychologist_client(p_psychologist_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.psychologist_clients
    where id = p_psychologist_client_id
      and patient_id = (select auth.uid())
  );
$$;
DROP FUNCTION IF EXISTS public.get_jwt_claim_role() CASCADE;
create or replace function public.get_jwt_claim_role()
returns text
language sql
stable
as $$
  select coalesce(
    (select current_setting('request.jwt.claims', true)::json->>'user_role'),
    null
  );
$$;
DROP FUNCTION IF EXISTS public.is_admin_or_own_psychologist(uuid) CASCADE;
create or replace function public.is_admin_or_own_psychologist(p_psychologist_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select 
    public.is_admin() or 
    p_psychologist_id = (select auth.uid());
$$;
DROP FUNCTION IF EXISTS public.is_psychologist_or_linked_patient(uuid, uuid) CASCADE;
create or replace function public.is_psychologist_or_linked_patient(p_psychologist_id uuid, p_psychologist_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select 
    p_psychologist_id = (select auth.uid()) or
    public.is_linked_to_psychologist_client(p_psychologist_client_id);
$$;
DROP FUNCTION IF EXISTS public.get_psychologist_ids_for_patient(uuid) CASCADE;
create or replace function public.get_psychologist_ids_for_patient(p_patient_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select psychologist_id
  from public.psychologist_clients
  where patient_id = p_patient_id
    and status = 'active';
$$;
DROP FUNCTION IF EXISTS public.get_active_patient_ids(uuid) CASCADE;
create or replace function public.get_active_patient_ids(p_psychologist_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select patient_id
  from public.psychologist_clients
  where psychologist_id = p_psychologist_id
    and status = 'active'
    and patient_id is not null;
$$;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  p_user_id uuid;
begin
  
  p_user_id := (event->>'user_id')::uuid;
  
  
  claims := coalesce(event->'claims', '{}'::jsonb);

  
  begin
    
    select role into user_role 
    from public.user_roles 
    where user_id = p_user_id;

    
    if user_role is not null then
      claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
    else
      claims := jsonb_set(claims, '{user_role}', 'null');
    end if;

    
    if user_role = 'psychologist' then
      select onboarding_completed into onboarding_status
      from public.psychologists
      where id = p_user_id;
      
      
      claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
    else
      
      claims := jsonb_set(claims, '{onboarding_completed}', 'true');
    end if;

  exception when others then
    
    
    claims := jsonb_set(claims, '{user_role}', 'null');
    claims := jsonb_set(claims, '{onboarding_completed}', 'false');
  end;

  
  event := jsonb_set(event, '{claims}', claims);

  
  return event;
end;
$$;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  sub_status text;
  p_user_id uuid;
begin
  
  p_user_id := (event->>'user_id')::uuid;
  
  
  claims := coalesce(event->'claims', '{}'::jsonb);

  
  begin
    
    select role into user_role 
    from public.user_roles 
    where user_id = p_user_id;

    
    if user_role is not null then
      claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
    else
      claims := jsonb_set(claims, '{user_role}', 'null');
    end if;

    
    if user_role = 'psychologist' then
      select onboarding_completed, subscription_status 
      into onboarding_status, sub_status
      from public.psychologists
      where id = p_user_id;
      
      
      claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
      
      
      claims := jsonb_set(claims, '{subscription_status}', to_jsonb(coalesce(sub_status, 'none')));
    else
      
      claims := jsonb_set(claims, '{onboarding_completed}', 'true');
      
      claims := jsonb_set(claims, '{subscription_status}', '"none"');
    end if;

  exception when others then
    
    
    claims := jsonb_set(claims, '{user_role}', 'null');
    claims := jsonb_set(claims, '{onboarding_completed}', 'false');
    claims := jsonb_set(claims, '{subscription_status}', '"none"');
  end;

  
  event := jsonb_set(event, '{claims}', claims);

  
  return event;
end;
$$;
DROP FUNCTION IF EXISTS public.get_user_by_email(text) CASCADE;
CREATE OR REPLACE FUNCTION public.get_user_by_email(email_input text)
RETURNS TABLE (id uuid, email text)
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN QUERY
  SELECT au.id, au.email::text
  FROM auth.users au
  WHERE lower(au.email) = lower(email_input);
END;
$$ LANGUAGE plpgsql;
DROP FUNCTION IF EXISTS public.handle_new_psychologist() CASCADE;
create or replace function public.handle_new_psychologist()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  
  if new.role = 'psychologist' then
    
    insert into public.psychologists (id, email)
    select new.user_id, email
    from auth.users
    where id = new.user_id
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.get_onboarding_status_by_user(uuid) CASCADE;
create or replace function public.get_onboarding_status_by_user(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_role public.app_role;
  p_status boolean;
begin
  if p_user_id is null then
    return false;
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return true;
  end if;
  
  
  select onboarding_completed into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, false);
end;
$$;
DROP FUNCTION IF EXISTS public.get_subscription_status_by_user(uuid) CASCADE;
create or replace function public.get_subscription_status_by_user(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  p_role public.app_role;
  p_status text;
begin
  if p_user_id is null then
    return 'none';
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return 'none';
  end if;
  
  
  select subscription_status into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, 'none');
end;
$$;
DROP FUNCTION IF EXISTS public.handle_new_session_charge() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_new_session_charge()
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
CREATE OR REPLACE FUNCTION public.handle_session_update_charge()
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
DROP FUNCTION IF EXISTS consolidate_existing_paid_charges() CASCADE;
CREATE OR REPLACE FUNCTION consolidate_existing_paid_charges()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    psych_record RECORD;
    week_record RECORD;
    week_start timestamptz;
    week_end timestamptz;
    week_start_date date;
    week_end_date date;
    total_amount integer;
    description_text text;
    category_id uuid;
    existing_entry_id uuid;
    charge_ids uuid[];
    processed_weeks text[];
    week_key text;
BEGIN
    
    SELECT id INTO category_id
    FROM financial_transaction_categories
    WHERE name = 'Psychological Service' AND type = 'INCOME'
    LIMIT 1;

    
    FOR psych_record IN
        SELECT DISTINCT psychologist_id
        FROM psychologist_client_charges
        WHERE payment_status = 'paid' AND paid_at IS NOT NULL
    LOOP
        
        processed_weeks := ARRAY[]::text[];

        
        FOR week_record IN
            SELECT DISTINCT
                psychologist_id,
                
                (date_trunc('week', paid_at::date)::date + 
                    CASE WHEN extract(dow from paid_at::date) = 0 THEN 0 ELSE -extract(dow from paid_at::date)::integer END) as week_start_calc,
                (date_trunc('week', paid_at::date)::date + 
                    CASE WHEN extract(dow from paid_at::date) = 0 THEN 0 ELSE -extract(dow from paid_at::date)::integer END + 6) as week_end_calc
            FROM psychologist_client_charges
            WHERE psychologist_id = psych_record.psychologist_id
                AND payment_status = 'paid'
                AND paid_at IS NOT NULL
            ORDER BY week_start_calc
        LOOP
            week_start_date := week_record.week_start_calc;
            week_end_date := week_record.week_end_calc;
            week_key := psych_record.psychologist_id::text || '_' || week_start_date::text;

            
            IF week_key = ANY(processed_weeks) THEN
                CONTINUE;
            END IF;

            processed_weeks := array_append(processed_weeks, week_key);

            week_start := week_start_date::timestamptz;
            week_end := (week_end_date::date + interval '1 day' - interval '1 second')::timestamptz;

            
            SELECT array_agg(id), sum(price_cents)
            INTO charge_ids, total_amount
            FROM psychologist_client_charges
            WHERE psychologist_id = psych_record.psychologist_id
                AND payment_status = 'paid'
                AND paid_at IS NOT NULL
                AND paid_at >= week_start
                AND paid_at <= week_end;

            
            IF charge_ids IS NULL OR total_amount IS NULL OR total_amount = 0 THEN
                CONTINUE;
            END IF;

            
            description_text := 'Sessões ' || 
                to_char(week_start_date, 'DD') || ' ' ||
                CASE extract(month from week_start_date)
                    WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
                    WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
                    WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
                    WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
                END || ' - ' ||
                to_char(week_end_date, 'DD') || ' ' ||
                CASE extract(month from week_end_date)
                    WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
                    WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
                    WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
                    WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
                END;

            
            SELECT id INTO existing_entry_id
            FROM psychologist_financial_entries
            WHERE psychologist_id = psych_record.psychologist_id
                AND type = 'income'
                AND description LIKE 'Sessões%'
                AND date_time >= week_start
                AND date_time <= week_end
            LIMIT 1;

            
            DELETE FROM psychologist_financial_entries
            WHERE psychologist_id = psych_record.psychologist_id
                AND type = 'income'
                AND billing_id = ANY(charge_ids)
                AND (description IS NULL OR description NOT LIKE 'Sessões%');

            IF existing_entry_id IS NOT NULL THEN
                
                UPDATE psychologist_financial_entries
                SET amount = total_amount,
                    description = description_text,
                    updated_at = now()
                WHERE id = existing_entry_id;
            ELSE
                
                INSERT INTO psychologist_financial_entries (
                    psychologist_id,
                    type,
                    amount,
                    description,
                    date_time,
                    transaction_category_id,
                    status,
                    created_by,
                    created_at
                )
                VALUES (
                    psych_record.psychologist_id,
                    'income',
                    total_amount,
                    description_text,
                    week_start,
                    category_id,
                    'confirmed',
                    psych_record.psychologist_id,
                    now()
                );
            END IF;
        END LOOP;
    END LOOP;
END;
$$;
DROP FUNCTION IF EXISTS public.get_user_id_by_email(text) CASCADE;
create or replace function public.get_user_id_by_email(p_email text)
returns uuid
language plpgsql
security definer
set search_path = auth, public
as $$
declare
  target_id uuid;
begin
  select id into target_id 
  from auth.users 
  where auth.users.email = p_email 
  limit 1;
  
  return target_id;
end;
$$;
DROP FUNCTION IF EXISTS public.cleanup_expired_patient_deletions() CASCADE;
CREATE OR REPLACE FUNCTION public.cleanup_expired_patient_deletions()
RETURNS TABLE (
  deleted_count integer,
  cleanup_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  WITH deleted_patients AS (
    DELETE FROM public.psychologist_clients
    WHERE deleted_at IS NOT NULL
      AND recovery_deadline IS NOT NULL
      AND recovery_deadline < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_deleted_count
  FROM deleted_patients;
  
  
  RAISE NOTICE 'Patient deletion cleanup completed at %. Deleted % expired patient(s).', 
    v_timestamp, v_deleted_count;
  
  
  RETURN QUERY SELECT v_deleted_count, v_timestamp;
END;
$$;
DROP FUNCTION IF EXISTS public.cleanup_expired_patient_deletions() CASCADE;
CREATE OR REPLACE FUNCTION public.cleanup_expired_patient_deletions()
RETURNS TABLE (
  deleted_count integer,
  cleanup_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  WITH deleted_patients AS (
    DELETE FROM public.psychologist_clients
    WHERE deleted_at IS NOT NULL
      AND recovery_deadline IS NOT NULL
      AND recovery_deadline < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_deleted_count
  FROM deleted_patients;
  
  
  INSERT INTO public.patient_deletion_audit_log (
    cleanup_timestamp,
    deleted_count,
    triggered_by,
    notes
  ) VALUES (
    v_timestamp,
    v_deleted_count,
    'pg_cron',
    format('Automatic cleanup removed %s expired patient(s)', v_deleted_count)
  );
  
  
  RAISE NOTICE 'Patient deletion cleanup completed at %. Deleted % expired patient(s).', 
    v_timestamp, v_deleted_count;
  
  
  RETURN QUERY SELECT v_deleted_count, v_timestamp;
END;
$$;
DROP FUNCTION IF EXISTS public.handle_user_preferences_audit() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_user_preferences_audit()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        NEW.updated_at = NOW();
        INSERT INTO public.user_preferences_audit_log (user_id, old_values, new_values, action)
        VALUES (NEW.user_id, to_jsonb(OLD), to_jsonb(NEW), 'UPDATE');
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO public.user_preferences_audit_log (user_id, old_values, new_values, action)
        VALUES (NEW.user_id, NULL, to_jsonb(NEW), 'INSERT');
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
DROP FUNCTION IF EXISTS public.update_psychologist_availability_updated_at() CASCADE;
create or replace function public.update_psychologist_availability_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.sync_practice_modality_to_profile() CASCADE;
CREATE OR REPLACE FUNCTION public.sync_practice_modality_to_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  
  IF NEW.practice_modality IS DISTINCT FROM OLD.practice_modality THEN
    UPDATE public.psychologist_profiles
    SET 
      practice_modality = NEW.practice_modality,
      updated_at = NOW()
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.auto_update_past_session_status() CASCADE;
CREATE OR REPLACE FUNCTION public.auto_update_past_session_status()
RETURNS TABLE (
  updated_count integer,
  update_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  
  
  
  WITH updated_sessions AS (
    UPDATE public.clinical_sessions
    SET 
      status = 'open',
      updated_at = v_timestamp
    WHERE 
      status = 'scheduled'
      AND start_time < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_updated_count
  FROM updated_sessions;
  
  
  IF v_updated_count > 0 THEN
    RAISE NOTICE 'Auto-updated % session(s) from scheduled to open at %', 
      v_updated_count, v_timestamp;
  END IF;
  
  
  RETURN QUERY SELECT v_updated_count, v_timestamp;
END;
$$;
DROP FUNCTION IF EXISTS get_public_psychologist_by_username(text) CASCADE;
CREATE OR REPLACE FUNCTION get_public_psychologist_by_username(p_username text)
RETURNS TABLE (
  id uuid,
  full_name text,
  avatar_url text,
  crp text,
  crp_state text,
  bio text,
  specialties jsonb
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.crp,
    p.crp_state,
    pp.bio, 
    pp.specialties::jsonb
  FROM psychologists p
  LEFT JOIN psychologist_profiles pp ON p.id = pp.id
  WHERE p.username = p_username;
END;
$$;
DROP FUNCTION IF EXISTS cleanup_orphaned_weekly_consolidations() CASCADE;
CREATE OR REPLACE FUNCTION cleanup_orphaned_weekly_consolidations()
RETURNS TABLE(
  deleted_count INTEGER,
  total_amount_removed INTEGER
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count INTEGER := 0;
  v_total_amount INTEGER := 0;
  v_entry RECORD;
  v_week_start TIMESTAMP;
  v_week_end TIMESTAMP;
  v_charges_count INTEGER;
BEGIN
  
  FOR v_entry IN 
    SELECT 
      id,
      psychologist_id,
      description,
      amount,
      date_time
    FROM psychologist_financial_entries
    WHERE type = 'income'
      AND description LIKE 'Serviços Prestados%'
    ORDER BY date_time DESC
  LOOP
    
    
    v_week_start := date_trunc('week', v_entry.date_time) + interval '1 day'; 
    v_week_end := v_week_start + interval '6 days 23 hours 59 minutes 59 seconds'; 
    
    
    SELECT COUNT(*)
    INTO v_charges_count
    FROM psychologist_client_charges
    WHERE psychologist_id = v_entry.psychologist_id
      AND payment_status = 'paid'
      AND paid_at >= v_week_start
      AND paid_at <= v_week_end
      AND paid_at IS NOT NULL;
    
    
    IF v_charges_count = 0 THEN
      RAISE NOTICE 'Deleting orphaned consolidation: % (ID: %, Amount: %)', 
        v_entry.description, v_entry.id, v_entry.amount;
      
      DELETE FROM psychologist_financial_entries
      WHERE id = v_entry.id;
      
      v_deleted_count := v_deleted_count + 1;
      v_total_amount := v_total_amount + v_entry.amount;
    END IF;
  END LOOP;
  
  RETURN QUERY SELECT v_deleted_count, v_total_amount;
END;
$$;
DROP FUNCTION IF EXISTS public.enforce_linktree_active_limit() CASCADE;
CREATE OR REPLACE FUNCTION public.enforce_linktree_active_limit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  active_count integer;
BEGIN
  IF NEW.is_active IS TRUE THEN
    SELECT COUNT(*)
      INTO active_count
      FROM public.linktree_links
     WHERE psychologist_id = NEW.psychologist_id
       AND is_active = TRUE
       AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000');

    IF active_count >= 4 THEN
      RAISE EXCEPTION 'Maximum of 4 active links allowed'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.sync_username_to_profile() CASCADE;
CREATE OR REPLACE FUNCTION public.sync_username_to_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    UPDATE public.psychologist_profiles
    SET
      slug = NEW.username,
      updated_at = NOW()
    WHERE id = NEW.id
      AND slug IS DISTINCT FROM NEW.username;
  END IF;

  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.sync_username_to_psychologist() CASCADE;
CREATE OR REPLACE FUNCTION public.sync_username_to_psychologist()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.slug IS DISTINCT FROM OLD.slug THEN
    UPDATE public.psychologists
    SET
      username = NEW.slug,
      updated_at = NOW()
    WHERE id = NEW.id
      AND username IS DISTINCT FROM NEW.slug;
  END IF;

  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS check_profile_completion(uuid) CASCADE;
CREATE OR REPLACE FUNCTION check_profile_completion(p_psychologist_id uuid)
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
DROP FUNCTION IF EXISTS check_profile_completion(uuid) CASCADE;
CREATE OR REPLACE FUNCTION check_profile_completion(p_psychologist_id uuid)
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
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  claims jsonb;
  user_role public.app_role;
BEGIN
  
  SELECT role INTO user_role FROM public.user_roles WHERE user_id = (event->>'user_id')::uuid;

  claims := event->'claims';

  IF user_role IS NOT NULL THEN
    
    claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
  ELSE
    claims := jsonb_set(claims, '{user_role}', 'null');
  END IF;

  
  event := jsonb_set(event, '{claims}', claims);

  
  RETURN event;
END;
$$;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  sub_status text;
  p_user_id uuid;
  p_avatar_url text;
  p_user_metadata jsonb;
  p_provider text;
  p_google_picture text;
  p_is_google_default_photo boolean;
begin
  
  p_user_id := (event->>'user_id')::uuid;
  
  
  claims := coalesce(event->'claims', '{}'::jsonb);

  
  
  p_user_metadata := coalesce(event->'raw_user_meta_data', '{}'::jsonb);
  p_google_picture := coalesce(p_user_metadata->>'picture', p_user_metadata->>'avatar_url', '');
  
  
  
  p_provider := null;
  
  
  if event->'identities' is not null and jsonb_array_length(event->'identities') > 0 then
    p_provider := event->'identities'->0->>'provider';
  end if;
  
  
  
  if p_provider is null and p_google_picture != '' and p_google_picture like '%googleusercontent.com%' then
    p_provider := 'google';
  end if;

  
  begin
    
    select role into user_role 
    from public.user_roles 
    where user_id = p_user_id;

    
    if user_role is not null then
      claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
    else
      claims := jsonb_set(claims, '{user_role}', 'null');
    end if;

    
    if user_role = 'psychologist' then
      select onboarding_completed, subscription_status, avatar_url
      into onboarding_status, sub_status, p_avatar_url
      from public.psychologists
      where id = p_user_id;
      
      
      claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
      
      
      claims := jsonb_set(claims, '{subscription_status}', to_jsonb(coalesce(sub_status, 'none')));
      
      
      
      
      
      
      if p_avatar_url is not null and p_avatar_url != '' then
        
        claims := jsonb_set(claims, '{avatar_url}', to_jsonb(p_avatar_url));
        claims := jsonb_set(claims, '{avatar_source}', '"custom"');
        claims := jsonb_set(claims, '{is_default_photo}', 'false');
      elsif p_provider = 'google' and p_google_picture != '' then
        
        
        
        p_is_google_default_photo := (
          p_google_picture like '%googleusercontent.com%' and
          (p_google_picture like '%=s96-c%' or 
           p_google_picture like '%=s128-c%' or 
           p_google_picture like '%photo.jpg%')
        );
        
        claims := jsonb_set(claims, '{avatar_url}', to_jsonb(p_google_picture));
        claims := jsonb_set(claims, '{avatar_source}', '"google"');
        claims := jsonb_set(claims, '{is_default_photo}', to_jsonb(p_is_google_default_photo));
      else
        
        claims := jsonb_set(claims, '{avatar_url}', 'null');
        claims := jsonb_set(claims, '{avatar_source}', '"none"');
        claims := jsonb_set(claims, '{is_default_photo}', 'false');
      end if;
      
      
      if p_provider is not null then
        claims := jsonb_set(claims, '{auth_provider}', to_jsonb(p_provider));
      end if;
    else
      
      claims := jsonb_set(claims, '{onboarding_completed}', 'true');
      
      claims := jsonb_set(claims, '{subscription_status}', '"none"');
      
      claims := jsonb_set(claims, '{avatar_url}', 'null');
      claims := jsonb_set(claims, '{avatar_source}', '"none"');
      claims := jsonb_set(claims, '{is_default_photo}', 'false');
    end if;

  exception when others then
    
    
    claims := jsonb_set(claims, '{user_role}', 'null');
    claims := jsonb_set(claims, '{onboarding_completed}', 'false');
    claims := jsonb_set(claims, '{subscription_status}', '"none"');
    claims := jsonb_set(claims, '{avatar_url}', 'null');
    claims := jsonb_set(claims, '{avatar_source}', '"none"');
    claims := jsonb_set(claims, '{is_default_photo}', 'false');
  end;

  
  event := jsonb_set(event, '{claims}', claims);

  
  return event;
end;
$$;
DROP FUNCTION IF EXISTS public.get_user_id_by_email(text) CASCADE;
CREATE OR REPLACE FUNCTION public.get_user_id_by_email(p_email text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  target_id uuid;
BEGIN
  SELECT id INTO target_id FROM auth.users WHERE email = p_email LIMIT 1;
  RETURN target_id;
END;
$$;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  p_user_id uuid;
begin
  
  p_user_id := (event->>'user_id')::uuid;
  
  
  select role into user_role 
  from public.user_roles 
  where user_id = p_user_id;

  claims := event->'claims';

  
  if user_role is not null then
    claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
  else
    claims := jsonb_set(claims, '{user_role}', 'null');
  end if;

  
  if user_role = 'psychologist' then
    select onboarding_completed into onboarding_status
    from public.psychologists
    where id = p_user_id;
    
    
    claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
  else
    
    claims := jsonb_set(claims, '{onboarding_completed}', 'true');
  end if;

  
  event := jsonb_set(event, '{claims}', claims);

  
  return event;
end;
$$;
DROP FUNCTION IF EXISTS public.complete_psychologist_onboarding() CASCADE;
create or replace function public.complete_psychologist_onboarding()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_user_id uuid;
  p_role public.app_role;
begin
  
  p_user_id := auth.uid();
  
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  if p_role != 'psychologist' then
    raise exception 'Only psychologists can complete onboarding';
  end if;
  
  
  update public.psychologists
  set 
    onboarding_completed = true,
    updated_at = now()
  where id = p_user_id;
  
  
  return true;
end;
$$;
DROP FUNCTION IF EXISTS public.get_onboarding_status() CASCADE;
create or replace function public.get_onboarding_status()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_user_id uuid;
  p_role public.app_role;
  p_status boolean;
begin
  
  p_user_id := auth.uid();
  
  if p_user_id is null then
    return false;
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return true;
  end if;
  
  
  select onboarding_completed into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, false);
end;
$$;
DROP FUNCTION IF EXISTS public.complete_psychologist_onboarding() CASCADE;
create or replace function public.complete_psychologist_onboarding()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_user_id uuid;
  p_role public.app_role;
begin
  
  p_user_id := auth.uid();
  
  if p_user_id is null then
    raise exception 'Not authenticated';
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  if p_role != 'psychologist' then
    raise exception 'Only psychologists can complete onboarding';
  end if;
  
  
  update public.psychologists
  set 
    onboarding_completed = true,
    updated_at = now()
  where id = p_user_id;
  
  
  return true;
end;
$$;
DROP FUNCTION IF EXISTS public.get_onboarding_status() CASCADE;
create or replace function public.get_onboarding_status()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_user_id uuid;
  p_role public.app_role;
  p_status boolean;
begin
  
  p_user_id := auth.uid();
  
  if p_user_id is null then
    return false;
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return true;
  end if;
  
  
  select onboarding_completed into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, false);
end;
$$;
DROP FUNCTION IF EXISTS public.handle_new_psychologist() CASCADE;
create or replace function public.handle_new_psychologist()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  
  if new.role = 'psychologist' then
    
    insert into public.psychologists (id)
    values (new.user_id)
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.update_psychologist_clients_updated_at() CASCADE;
create or replace function public.update_psychologist_clients_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.update_clinical_sessions_updated_at() CASCADE;
create or replace function public.update_clinical_sessions_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.empty_lexical_state_base64() CASCADE;
create or replace function public.empty_lexical_state_base64()
returns text
language sql
immutable
as $$
  select encode('{"root":{"children":[{"children":[],"direction":null,"format":"","indent":0,"type":"paragraph","version":1}],"direction":null,"format":"","indent":0,"type":"root","version":1}}'::bytea, 'base64');
$$;
DROP FUNCTION IF EXISTS public.text_to_lexical_base64(text) CASCADE;
create or replace function public.text_to_lexical_base64(input_text text)
returns text
language sql
immutable
as $$
  select encode(
    format(
      '{"root":{"children":[{"children":[{"detail":0,"format":0,"mode":"normal","style":"","text":"%s","type":"text","version":1}],"direction":"ltr","format":"","indent":0,"type":"paragraph","version":1}],"direction":"ltr","format":"","indent":0,"type":"root","version":1}}',
      replace(replace(replace(input_text, '\', '\\'), '"', '\"'), E'\n', '\n')
    )::bytea,
    'base64'
  );
$$;
DROP FUNCTION IF EXISTS public.is_webhook_event_processed(text) CASCADE;
create or replace function public.is_webhook_event_processed(p_event_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.webhook_events
    where event_id = p_event_id
  );
$$;
DROP FUNCTION IF EXISTS public.update_psychologist_subscriptions_trigger() CASCADE;
create or replace function public.update_psychologist_subscriptions_trigger()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  
  new.has_active_subscription = (
    new.status in ('active', 'trialing') and 
    (new.current_period_end is null or new.current_period_end > now())
  );
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.check_subscription_access(uuid) CASCADE;
create or replace function public.check_subscription_access(p_therapist_id uuid)
returns table (
  status text,
  has_access boolean,
  trial_end timestamptz,
  current_period_end timestamptz,
  days_remaining integer,
  is_in_grace_period boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_sub record;
  v_grace_period interval := interval '3 days';
begin
  select * into v_sub
  from public.psychologist_subscriptions
  where psychologist_id = p_therapist_id;
  
  if not found then
    return query select 
      'inactive'::text,
      false,
      null::timestamptz,
      null::timestamptz,
      0,
      false;
    return;
  end if;
  
  return query select
    v_sub.status,
    v_sub.has_active_subscription or 
      (v_sub.current_period_end is not null and v_sub.current_period_end + v_grace_period > now()),
    v_sub.trial_ends_at,
    v_sub.current_period_end,
    case 
      when v_sub.current_period_end is null then 0
      else greatest(0, extract(day from v_sub.current_period_end - now()))::integer
    end,
    v_sub.current_period_end is not null and 
      v_sub.current_period_end < now() and 
      v_sub.current_period_end + v_grace_period > now();
end;
$$;
DROP FUNCTION IF EXISTS public.broadcast_subscription_update(uuid) CASCADE;
create or replace function public.broadcast_subscription_update(p_therapist_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  
  
  perform pg_notify(
    'subscription_updated',
    json_build_object('psychologist_id', p_therapist_id)::text
  );
end;
$$;
DROP FUNCTION IF EXISTS public.get_user_role(uuid) CASCADE;
create or replace function public.get_user_role(p_user_id uuid)
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.user_roles
  where user_id = p_user_id
  limit 1;
$$;
DROP FUNCTION IF EXISTS public.current_user_role() CASCADE;
create or replace function public.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.user_roles
  where user_id = (select auth.uid())
  limit 1;
$$;
DROP FUNCTION IF EXISTS public.user_has_role(uuid, public.app_role) CASCADE;
create or replace function public.user_has_role(p_user_id uuid, p_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = p_user_id
      and role = p_role
  );
$$;
DROP FUNCTION IF EXISTS public.is_psychologist() CASCADE;
create or replace function public.is_psychologist()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'psychologist'
  );
$$;
DROP FUNCTION IF EXISTS public.is_patient() CASCADE;
create or replace function public.is_patient()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'patient'
  );
$$;
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'admin'
  );
$$;
DROP FUNCTION IF EXISTS public.is_assistant() CASCADE;
create or replace function public.is_assistant()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = (select auth.uid())
      and role = 'assistant'
  );
$$;
DROP FUNCTION IF EXISTS public.is_own_psychologist_data(uuid) CASCADE;
create or replace function public.is_own_psychologist_data(p_psychologist_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_psychologist_id = (select auth.uid());
$$;
DROP FUNCTION IF EXISTS public.is_own_patient_data(uuid) CASCADE;
create or replace function public.is_own_patient_data(p_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_patient_id = (select auth.uid());
$$;
DROP FUNCTION IF EXISTS public.has_client_access(uuid) CASCADE;
create or replace function public.has_client_access(p_psychologist_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.psychologist_clients
    where id = p_psychologist_client_id
      and psychologist_id = (select auth.uid())
  );
$$;
DROP FUNCTION IF EXISTS public.is_linked_to_psychologist_client(uuid) CASCADE;
create or replace function public.is_linked_to_psychologist_client(p_psychologist_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.psychologist_clients
    where id = p_psychologist_client_id
      and patient_id = (select auth.uid())
  );
$$;
DROP FUNCTION IF EXISTS public.get_jwt_claim_role() CASCADE;
create or replace function public.get_jwt_claim_role()
returns text
language sql
stable
as $$
  select coalesce(
    (select current_setting('request.jwt.claims', true)::json->>'user_role'),
    null
  );
$$;
DROP FUNCTION IF EXISTS public.is_admin_or_own_psychologist(uuid) CASCADE;
create or replace function public.is_admin_or_own_psychologist(p_psychologist_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select 
    public.is_admin() or 
    p_psychologist_id = (select auth.uid());
$$;
DROP FUNCTION IF EXISTS public.is_psychologist_or_linked_patient(uuid, uuid) CASCADE;
create or replace function public.is_psychologist_or_linked_patient(p_psychologist_id uuid, p_psychologist_client_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select 
    p_psychologist_id = (select auth.uid()) or
    public.is_linked_to_psychologist_client(p_psychologist_client_id);
$$;
DROP FUNCTION IF EXISTS public.get_psychologist_ids_for_patient(uuid) CASCADE;
create or replace function public.get_psychologist_ids_for_patient(p_patient_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select psychologist_id
  from public.psychologist_clients
  where patient_id = p_patient_id
    and status = 'active';
$$;
DROP FUNCTION IF EXISTS public.get_active_patient_ids(uuid) CASCADE;
create or replace function public.get_active_patient_ids(p_psychologist_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select patient_id
  from public.psychologist_clients
  where psychologist_id = p_psychologist_id
    and status = 'active'
    and patient_id is not null;
$$;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  p_user_id uuid;
begin
  
  p_user_id := (event->>'user_id')::uuid;
  
  
  claims := coalesce(event->'claims', '{}'::jsonb);

  
  begin
    
    select role into user_role 
    from public.user_roles 
    where user_id = p_user_id;

    
    if user_role is not null then
      claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
    else
      claims := jsonb_set(claims, '{user_role}', 'null');
    end if;

    
    if user_role = 'psychologist' then
      select onboarding_completed into onboarding_status
      from public.psychologists
      where id = p_user_id;
      
      
      claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
    else
      
      claims := jsonb_set(claims, '{onboarding_completed}', 'true');
    end if;

  exception when others then
    
    
    claims := jsonb_set(claims, '{user_role}', 'null');
    claims := jsonb_set(claims, '{onboarding_completed}', 'false');
  end;

  
  event := jsonb_set(event, '{claims}', claims);

  
  return event;
end;
$$;
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb) CASCADE;
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_role public.app_role;
  onboarding_status boolean;
  sub_status text;
  p_user_id uuid;
begin
  
  p_user_id := (event->>'user_id')::uuid;
  
  
  claims := coalesce(event->'claims', '{}'::jsonb);

  
  begin
    
    select role into user_role 
    from public.user_roles 
    where user_id = p_user_id;

    
    if user_role is not null then
      claims := jsonb_set(claims, '{user_role}', to_jsonb(user_role));
    else
      claims := jsonb_set(claims, '{user_role}', 'null');
    end if;

    
    if user_role = 'psychologist' then
      select onboarding_completed, subscription_status 
      into onboarding_status, sub_status
      from public.psychologists
      where id = p_user_id;
      
      
      claims := jsonb_set(claims, '{onboarding_completed}', to_jsonb(coalesce(onboarding_status, false)));
      
      
      claims := jsonb_set(claims, '{subscription_status}', to_jsonb(coalesce(sub_status, 'none')));
    else
      
      claims := jsonb_set(claims, '{onboarding_completed}', 'true');
      
      claims := jsonb_set(claims, '{subscription_status}', '"none"');
    end if;

  exception when others then
    
    
    claims := jsonb_set(claims, '{user_role}', 'null');
    claims := jsonb_set(claims, '{onboarding_completed}', 'false');
    claims := jsonb_set(claims, '{subscription_status}', '"none"');
  end;

  
  event := jsonb_set(event, '{claims}', claims);

  
  return event;
end;
$$;
DROP FUNCTION IF EXISTS public.handle_new_psychologist() CASCADE;
create or replace function public.handle_new_psychologist()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  
  if new.role = 'psychologist' then
    
    insert into public.psychologists (id, email)
    select new.user_id, email
    from auth.users
    where id = new.user_id
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.get_onboarding_status_by_user(uuid) CASCADE;
create or replace function public.get_onboarding_status_by_user(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_role public.app_role;
  p_status boolean;
begin
  if p_user_id is null then
    return false;
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return true;
  end if;
  
  
  select onboarding_completed into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, false);
end;
$$;
DROP FUNCTION IF EXISTS public.get_subscription_status_by_user(uuid) CASCADE;
create or replace function public.get_subscription_status_by_user(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  p_role public.app_role;
  p_status text;
begin
  if p_user_id is null then
    return 'none';
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return 'none';
  end if;
  
  
  select subscription_status into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, 'none');
end;
$$;
DROP FUNCTION IF EXISTS public.get_onboarding_status_by_user(uuid) CASCADE;
create or replace function public.get_onboarding_status_by_user(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  p_role public.app_role;
  p_status boolean;
begin
  if p_user_id is null then
    return false;
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return true;
  end if;
  
  
  select onboarding_completed into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, false);
end;
$$;
DROP FUNCTION IF EXISTS public.get_subscription_status_by_user(uuid) CASCADE;
create or replace function public.get_subscription_status_by_user(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  p_role public.app_role;
  p_status text;
begin
  if p_user_id is null then
    return 'none';
  end if;
  
  
  select role into p_role
  from public.user_roles
  where user_id = p_user_id;
  
  
  if p_role is null or p_role != 'psychologist' then
    return 'none';
  end if;
  
  
  select subscription_status into p_status
  from public.psychologists
  where id = p_user_id;
  
  return coalesce(p_status, 'none');
end;
$$;
DROP FUNCTION IF EXISTS consolidate_existing_paid_charges() CASCADE;
CREATE OR REPLACE FUNCTION consolidate_existing_paid_charges()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    psych_record RECORD;
    week_record RECORD;
    week_start timestamptz;
    week_end timestamptz;
    week_start_date date;
    week_end_date date;
    total_amount integer;
    description_text text;
    category_id uuid;
    existing_entry_id uuid;
    charge_ids uuid[];
    processed_weeks text[];
    week_key text;
BEGIN
    
    SELECT id INTO category_id
    FROM financial_transaction_categories
    WHERE name = 'Psychological Service' AND type = 'INCOME'
    LIMIT 1;

    
    FOR psych_record IN
        SELECT DISTINCT psychologist_id
        FROM psychologist_client_charges
        WHERE payment_status = 'paid' AND paid_at IS NOT NULL
    LOOP
        
        processed_weeks := ARRAY[]::text[];

        
        FOR week_record IN
            SELECT DISTINCT
                psychologist_id,
                
                (date_trunc('week', paid_at::date)::date + 
                    CASE WHEN extract(dow from paid_at::date) = 0 THEN 0 ELSE -extract(dow from paid_at::date)::integer END) as week_start_calc,
                (date_trunc('week', paid_at::date)::date + 
                    CASE WHEN extract(dow from paid_at::date) = 0 THEN 0 ELSE -extract(dow from paid_at::date)::integer END + 6) as week_end_calc
            FROM psychologist_client_charges
            WHERE psychologist_id = psych_record.psychologist_id
                AND payment_status = 'paid'
                AND paid_at IS NOT NULL
            ORDER BY week_start_calc
        LOOP
            week_start_date := week_record.week_start_calc;
            week_end_date := week_record.week_end_calc;
            week_key := psych_record.psychologist_id::text || '_' || week_start_date::text;

            
            IF week_key = ANY(processed_weeks) THEN
                CONTINUE;
            END IF;

            processed_weeks := array_append(processed_weeks, week_key);

            week_start := week_start_date::timestamptz;
            week_end := (week_end_date::date + interval '1 day' - interval '1 second')::timestamptz;

            
            SELECT array_agg(id), sum(price_cents)
            INTO charge_ids, total_amount
            FROM psychologist_client_charges
            WHERE psychologist_id = psych_record.psychologist_id
                AND payment_status = 'paid'
                AND paid_at IS NOT NULL
                AND paid_at >= week_start
                AND paid_at <= week_end;

            
            IF charge_ids IS NULL OR total_amount IS NULL OR total_amount = 0 THEN
                CONTINUE;
            END IF;

            
            description_text := 'Sessões ' || 
                to_char(week_start_date, 'DD') || ' ' ||
                CASE extract(month from week_start_date)
                    WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
                    WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
                    WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
                    WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
                END || ' - ' ||
                to_char(week_end_date, 'DD') || ' ' ||
                CASE extract(month from week_end_date)
                    WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
                    WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
                    WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
                    WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
                END;

            
            SELECT id INTO existing_entry_id
            FROM psychologist_financial_entries
            WHERE psychologist_id = psych_record.psychologist_id
                AND type = 'income'
                AND description LIKE 'Sessões%'
                AND date_time >= week_start
                AND date_time <= week_end
            LIMIT 1;

            
            DELETE FROM psychologist_financial_entries
            WHERE psychologist_id = psych_record.psychologist_id
                AND type = 'income'
                AND billing_id = ANY(charge_ids)
                AND (description IS NULL OR description NOT LIKE 'Sessões%');

            IF existing_entry_id IS NOT NULL THEN
                
                UPDATE psychologist_financial_entries
                SET amount = total_amount,
                    description = description_text,
                    updated_at = now()
                WHERE id = existing_entry_id;
            ELSE
                
                INSERT INTO psychologist_financial_entries (
                    psychologist_id,
                    type,
                    amount,
                    description,
                    date_time,
                    transaction_category_id,
                    status,
                    created_by,
                    created_at
                )
                VALUES (
                    psych_record.psychologist_id,
                    'income',
                    total_amount,
                    description_text,
                    week_start,
                    category_id,
                    'confirmed',
                    psych_record.psychologist_id,
                    now()
                );
            END IF;
        END LOOP;
    END LOOP;
END;
$$;
DROP FUNCTION IF EXISTS public.get_user_id_by_email(text) CASCADE;
create or replace function public.get_user_id_by_email(p_email text)
returns uuid
language plpgsql
security definer
set search_path = auth, public
as $$
declare
  target_id uuid;
begin
  select id into target_id 
  from auth.users 
  where auth.users.email = p_email 
  limit 1;
  
  return target_id;
end;
$$;
DROP FUNCTION IF EXISTS public.cleanup_expired_patient_deletions() CASCADE;
CREATE OR REPLACE FUNCTION public.cleanup_expired_patient_deletions()
RETURNS TABLE (
  deleted_count integer,
  cleanup_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  WITH deleted_patients AS (
    DELETE FROM public.psychologist_clients
    WHERE deleted_at IS NOT NULL
      AND recovery_deadline IS NOT NULL
      AND recovery_deadline < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_deleted_count
  FROM deleted_patients;
  
  
  RAISE NOTICE 'Patient deletion cleanup completed at %. Deleted % expired patient(s).', 
    v_timestamp, v_deleted_count;
  
  
  RETURN QUERY SELECT v_deleted_count, v_timestamp;
END;
$$;
DROP FUNCTION IF EXISTS public.cleanup_expired_patient_deletions() CASCADE;
CREATE OR REPLACE FUNCTION public.cleanup_expired_patient_deletions()
RETURNS TABLE (
  deleted_count integer,
  cleanup_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  WITH deleted_patients AS (
    DELETE FROM public.psychologist_clients
    WHERE deleted_at IS NOT NULL
      AND recovery_deadline IS NOT NULL
      AND recovery_deadline < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_deleted_count
  FROM deleted_patients;
  
  
  INSERT INTO public.patient_deletion_audit_log (
    cleanup_timestamp,
    deleted_count,
    triggered_by,
    notes
  ) VALUES (
    v_timestamp,
    v_deleted_count,
    'pg_cron',
    format('Automatic cleanup removed %s expired patient(s)', v_deleted_count)
  );
  
  
  RAISE NOTICE 'Patient deletion cleanup completed at %. Deleted % expired patient(s).', 
    v_timestamp, v_deleted_count;
  
  
  RETURN QUERY SELECT v_deleted_count, v_timestamp;
END;
$$;
DROP FUNCTION IF EXISTS public.update_psychologist_availability_updated_at() CASCADE;
create or replace function public.update_psychologist_availability_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
DROP FUNCTION IF EXISTS public.sync_practice_modality_to_profile() CASCADE;
CREATE OR REPLACE FUNCTION public.sync_practice_modality_to_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  
  IF NEW.practice_modality IS DISTINCT FROM OLD.practice_modality THEN
    UPDATE public.psychologist_profiles
    SET 
      practice_modality = NEW.practice_modality,
      updated_at = NOW()
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.sync_practice_modality_to_profile() CASCADE;
CREATE OR REPLACE FUNCTION public.sync_practice_modality_to_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  
  IF NEW.practice_modality IS DISTINCT FROM OLD.practice_modality THEN
    UPDATE public.psychologist_profiles
    SET 
      practice_modality = NEW.practice_modality,
      updated_at = NOW()
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.auto_update_past_session_status() CASCADE;
CREATE OR REPLACE FUNCTION public.auto_update_past_session_status()
RETURNS TABLE (
  updated_count integer,
  update_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  
  
  
  WITH updated_sessions AS (
    UPDATE public.clinical_sessions
    SET 
      status = 'open',
      updated_at = v_timestamp
    WHERE 
      status = 'scheduled'
      AND start_time < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_updated_count
  FROM updated_sessions;
  
  
  IF v_updated_count > 0 THEN
    RAISE NOTICE 'Auto-updated % session(s) from scheduled to open at %', 
      v_updated_count, v_timestamp;
  END IF;
  
  
  RETURN QUERY SELECT v_updated_count, v_timestamp;
END;
$$;
DROP FUNCTION IF EXISTS public.auto_update_past_session_status() CASCADE;
CREATE OR REPLACE FUNCTION public.auto_update_past_session_status()
RETURNS TABLE (
  updated_count integer,
  update_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  
  
  
  WITH updated_sessions AS (
    UPDATE public.clinical_sessions
    SET 
      status = 'open',
      updated_at = v_timestamp
    WHERE 
      status = 'scheduled'
      AND start_time < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_updated_count
  FROM updated_sessions;
  
  
  IF v_updated_count > 0 THEN
    RAISE NOTICE 'Auto-updated % session(s) from scheduled to open at %', 
      v_updated_count, v_timestamp;
  END IF;
  
  
  RETURN QUERY SELECT v_updated_count, v_timestamp;
END;
$$;
DROP FUNCTION IF EXISTS get_public_psychologist_by_username(text) CASCADE;
CREATE OR REPLACE FUNCTION get_public_psychologist_by_username(p_username text)
RETURNS TABLE (
  id uuid,
  full_name text,
  avatar_url text,
  crp text,
  crp_state text,
  bio text,
  specialties jsonb
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.crp,
    p.crp_state,
    pp.bio, 
    pp.specialties::jsonb
  FROM psychologists p
  LEFT JOIN psychologist_profiles pp ON p.id = pp.id
  WHERE p.username = p_username;
END;
$$;
DROP FUNCTION IF EXISTS cleanup_orphaned_weekly_consolidations() CASCADE;
CREATE OR REPLACE FUNCTION cleanup_orphaned_weekly_consolidations()
RETURNS TABLE(
  deleted_count INTEGER,
  total_amount_removed INTEGER
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count INTEGER := 0;
  v_total_amount INTEGER := 0;
  v_entry RECORD;
  v_week_start TIMESTAMP;
  v_week_end TIMESTAMP;
  v_charges_count INTEGER;
BEGIN
  
  FOR v_entry IN 
    SELECT 
      id,
      psychologist_id,
      description,
      amount,
      date_time
    FROM psychologist_financial_entries
    WHERE type = 'income'
      AND description LIKE 'Serviços Prestados%'
    ORDER BY date_time DESC
  LOOP
    
    
    v_week_start := date_trunc('week', v_entry.date_time) + interval '1 day'; 
    v_week_end := v_week_start + interval '6 days 23 hours 59 minutes 59 seconds'; 
    
    
    SELECT COUNT(*)
    INTO v_charges_count
    FROM psychologist_client_charges
    WHERE psychologist_id = v_entry.psychologist_id
      AND payment_status = 'paid'
      AND paid_at >= v_week_start
      AND paid_at <= v_week_end
      AND paid_at IS NOT NULL;
    
    
    IF v_charges_count = 0 THEN
      RAISE NOTICE 'Deleting orphaned consolidation: % (ID: %, Amount: %)', 
        v_entry.description, v_entry.id, v_entry.amount;
      
      DELETE FROM psychologist_financial_entries
      WHERE id = v_entry.id;
      
      v_deleted_count := v_deleted_count + 1;
      v_total_amount := v_total_amount + v_entry.amount;
    END IF;
  END LOOP;
  
  RETURN QUERY SELECT v_deleted_count, v_total_amount;
END;
$$;
DROP FUNCTION IF EXISTS public.enforce_linktree_active_limit() CASCADE;
CREATE OR REPLACE FUNCTION public.enforce_linktree_active_limit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  active_count integer;
BEGIN
  IF NEW.is_active IS TRUE THEN
    SELECT COUNT(*)
      INTO active_count
      FROM public.linktree_links
     WHERE psychologist_id = NEW.psychologist_id
       AND is_active = TRUE
       AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000');

    IF active_count >= 4 THEN
      RAISE EXCEPTION 'Maximum of 4 active links allowed'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.sync_username_to_profile() CASCADE;
CREATE OR REPLACE FUNCTION public.sync_username_to_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.username IS DISTINCT FROM OLD.username THEN
    UPDATE public.psychologist_profiles
    SET
      slug = NEW.username,
      updated_at = NOW()
    WHERE id = NEW.id
      AND slug IS DISTINCT FROM NEW.username;
  END IF;

  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.sync_username_to_psychologist() CASCADE;
CREATE OR REPLACE FUNCTION public.sync_username_to_psychologist()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.slug IS DISTINCT FROM OLD.slug THEN
    UPDATE public.psychologists
    SET
      username = NEW.slug,
      updated_at = NOW()
    WHERE id = NEW.id
      AND username IS DISTINCT FROM NEW.slug;
  END IF;

  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS check_profile_completion(uuid) CASCADE;
CREATE OR REPLACE FUNCTION check_profile_completion(p_psychologist_id uuid)
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
DROP FUNCTION IF EXISTS check_profile_completion(uuid) CASCADE;
CREATE OR REPLACE FUNCTION check_profile_completion(p_psychologist_id uuid)
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
DROP FUNCTION IF EXISTS check_profile_completion(uuid) CASCADE;
CREATE OR REPLACE FUNCTION check_profile_completion(p_psychologist_id uuid)
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
DROP FUNCTION IF EXISTS check_profile_completion(uuid) CASCADE;
CREATE OR REPLACE FUNCTION check_profile_completion(p_psychologist_id uuid)
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
DROP FUNCTION IF EXISTS public.encrypt_token_base64(text, text) CASCADE;
CREATE OR REPLACE FUNCTION public.encrypt_token_base64(token text, encryption_key text)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT encode(extensions.pgp_sym_encrypt(token, encryption_key), 'base64');
$$;
DROP FUNCTION IF EXISTS public.decrypt_token_base64(text, text) CASCADE;
CREATE OR REPLACE FUNCTION public.decrypt_token_base64(encrypted_token_base64 text, encryption_key text)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT extensions.pgp_sym_decrypt(decode(encrypted_token_base64, 'base64'), encryption_key)::text;
$$;
DROP FUNCTION IF EXISTS public.cleanup_expired_patient_deletions() CASCADE;
CREATE OR REPLACE FUNCTION public.cleanup_expired_patient_deletions()
RETURNS TABLE (
  deleted_count integer,
  cleanup_timestamp timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count integer;
  v_timestamp timestamptz;
BEGIN
  v_timestamp := now();
  
  
  WITH deleted_patients AS (
    DELETE FROM public.psychologist_clients
    WHERE deleted_at IS NOT NULL
      AND recovery_deadline IS NOT NULL
      AND recovery_deadline < v_timestamp
    RETURNING id
  )
  SELECT count(*)::integer INTO v_deleted_count
  FROM deleted_patients;
  
  
  INSERT INTO public.patient_deletion_audit_log (
    cleanup_timestamp,
    deleted_count,
    triggered_by,
    notes
  ) VALUES (
    v_timestamp,
    v_deleted_count,
    'manual_or_cron',
    format('Cleanup removendo %s paciente(s) com prazo expirado', v_deleted_count)
  );
  
  RETURN QUERY SELECT v_deleted_count, v_timestamp;
END;
$$;
DROP FUNCTION IF EXISTS public.update_patient_session_stats() CASCADE;
CREATE OR REPLACE FUNCTION public.update_patient_session_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    UPDATE public.psychologist_clients
    SET 
      last_session_date = NEW.start_time::date,
      total_sessions_count = COALESCE(total_sessions_count, 0) + 1,
      updated_at = NOW()
    WHERE id = NEW.psychologist_client_id;
  END IF;
  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.trigger_consolidate_weekly_charges() CASCADE;
CREATE OR REPLACE FUNCTION public.trigger_consolidate_weekly_charges()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.payment_status = 'paid' AND NEW.paid_at IS NOT NULL THEN
    PERFORM public.consolidate_weekly_charges(NEW.psychologist_id, NEW.paid_at);
  ELSIF TG_OP = 'UPDATE' AND OLD.payment_status = 'paid' AND NEW.payment_status != 'paid' THEN
    IF OLD.paid_at IS NOT NULL THEN
      PERFORM public.consolidate_weekly_charges(OLD.psychologist_id, OLD.paid_at);
    END IF;
  ELSIF TG_OP = 'DELETE' AND OLD.payment_status = 'paid' AND OLD.paid_at IS NOT NULL THEN
    PERFORM public.consolidate_weekly_charges(OLD.psychologist_id, OLD.paid_at);
  END IF;
  RETURN NEW;
END;
$$;
DROP FUNCTION IF EXISTS public.validate_financial_entry_category() CASCADE;
CREATE OR REPLACE FUNCTION public.validate_financial_entry_category()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category_type public.transaction_type;
BEGIN
  IF NEW.transaction_category_id IS NOT NULL THEN
    SELECT type INTO v_category_type
    FROM public.financial_transaction_categories
    WHERE id = NEW.transaction_category_id;
    
    IF v_category_type IS NULL THEN
      RAISE EXCEPTION 'Categoria não encontrada';
    END IF;
    
    IF (NEW.type = 'income' AND v_category_type != 'INCOME') OR
       (NEW.type = 'expense' AND v_category_type != 'EXPENSE') THEN
      RAISE EXCEPTION 'Categoria incompatível com o tipo de lançamento';
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_sessions' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS on_session_created_charge ON public.clinical_sessions;
        CREATE TRIGGER on_session_created_charge
    AFTER INSERT ON public.clinical_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_session_charge();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_sessions' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS on_session_updated_charge ON public.clinical_sessions;
        CREATE TRIGGER on_session_updated_charge
    AFTER UPDATE ON public.clinical_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_session_update_charge();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_preferences' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS trigger_user_preferences_audit ON public.user_preferences;
        CREATE TRIGGER trigger_user_preferences_audit
    AFTER INSERT OR UPDATE ON public.user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_user_preferences_audit();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologists' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS sync_practice_modality_trigger ON public.psychologists;
        CREATE TRIGGER sync_practice_modality_trigger
  AFTER UPDATE OF practice_modality ON public.psychologists
  FOR EACH ROW
  WHEN (NEW.practice_modality IS DISTINCT FROM OLD.practice_modality)
  EXECUTE FUNCTION public.sync_practice_modality_to_profile();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'linktree_links' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS trg_enforce_linktree_active_limit ON public.linktree_links;
        CREATE TRIGGER trg_enforce_linktree_active_limit
BEFORE INSERT OR UPDATE OF is_active ON public.linktree_links
FOR EACH ROW
EXECUTE FUNCTION public.enforce_linktree_active_limit();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_profiles' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS sync_username_to_psychologist_trigger ON public.psychologist_profiles;
        CREATE TRIGGER sync_username_to_psychologist_trigger
  AFTER UPDATE OF slug ON public.psychologist_profiles
  FOR EACH ROW
  WHEN (NEW.slug IS DISTINCT FROM OLD.slug)
  EXECUTE FUNCTION public.sync_username_to_psychologist();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_sessions' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS on_session_created_charge ON public.clinical_sessions;
        CREATE TRIGGER on_session_created_charge
    AFTER INSERT ON public.clinical_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_session_charge();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_sessions' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS on_session_updated_charge ON public.clinical_sessions;
        CREATE TRIGGER on_session_updated_charge
    AFTER UPDATE ON public.clinical_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_session_update_charge();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_preferences' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS trigger_user_preferences_audit ON public.user_preferences;
        CREATE TRIGGER trigger_user_preferences_audit
    AFTER INSERT OR UPDATE ON public.user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_user_preferences_audit();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologists' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS sync_practice_modality_trigger ON public.psychologists;
        CREATE TRIGGER sync_practice_modality_trigger
  AFTER UPDATE OF practice_modality ON public.psychologists
  FOR EACH ROW
  WHEN (NEW.practice_modality IS DISTINCT FROM OLD.practice_modality)
  EXECUTE FUNCTION public.sync_practice_modality_to_profile();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'linktree_links' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS trg_enforce_linktree_active_limit ON public.linktree_links;
        CREATE TRIGGER trg_enforce_linktree_active_limit
BEFORE INSERT OR UPDATE OF is_active ON public.linktree_links
FOR EACH ROW
EXECUTE FUNCTION public.enforce_linktree_active_limit();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_profiles' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS sync_username_to_psychologist_trigger ON public.psychologist_profiles;
        CREATE TRIGGER sync_username_to_psychologist_trigger
  AFTER UPDATE OF slug ON public.psychologist_profiles
  FOR EACH ROW
  WHEN (NEW.slug IS DISTINCT FROM OLD.slug)
  EXECUTE FUNCTION public.sync_username_to_psychologist();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'clinical_sessions' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS on_session_completed_stats ON public.clinical_sessions;
        CREATE TRIGGER on_session_completed_stats
  AFTER UPDATE ON public.clinical_sessions
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed'))
  EXECUTE FUNCTION public.update_patient_session_stats();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_client_charges' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS on_charge_paid_consolidate ON public.psychologist_client_charges;
        CREATE TRIGGER on_charge_paid_consolidate
  AFTER INSERT OR UPDATE OR DELETE ON public.psychologist_client_charges
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_consolidate_weekly_charges();
    END IF;
END $$;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'psychologist_financial_entries' AND schemaname = 'public') THEN
        DROP TRIGGER IF EXISTS validate_entry_category ON public.psychologist_financial_entries;
        CREATE TRIGGER validate_entry_category
  BEFORE INSERT OR UPDATE ON public.psychologist_financial_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_financial_entry_category();
    END IF;
END $$;
