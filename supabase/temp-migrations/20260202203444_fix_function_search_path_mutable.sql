-- Migration: Fix Function Search Path Mutable
-- Created at: 2026-02-02 20:34:44
-- Issue: Functions without explicit search_path parameter
-- Fix: Add SET search_path = '' to all affected functions
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable

-- Fix 1: public.handle_stripe_subscription_update
CREATE OR REPLACE FUNCTION public.handle_stripe_subscription_update()
RETURNS TRIGGER AS $$
DECLARE
    v_psychologist_id UUID;
BEGIN
    v_psychologist_id := (NEW.metadata->>'psychologist_id')::UUID;

    IF v_psychologist_id IS NOT NULL THEN
        UPDATE public.psychologists
        SET 
            subscription_status = NEW.status,
            stripe_subscription_id = NEW.id,
            updated_at = NOW()
        WHERE id = v_psychologist_id;
        
        IF NEW.status = 'active' OR NEW.status = 'trialing' THEN
            UPDATE public.psychologist_onboarding_state
            SET 
                onboarding_completed_at = COALESCE(onboarding_completed_at, NOW()),
                updated_at = NOW()
            WHERE psychologist_id = v_psychologist_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = '';
-- Fix 2: public.get_upcoming_exceptions
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
SET search_path = ''
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
-- Fix 3: public.has_access_to_psychologist_data
CREATE OR REPLACE FUNCTION public.has_access_to_psychologist_data(target_psychologist_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT (
        auth.uid() = target_psychologist_id
        OR
        EXISTS (
            SELECT 1 
            FROM public.psychologist_assistants 
            WHERE psychologist_id = target_psychologist_id 
            AND assistant_id = auth.uid()
        )
    );
$$;
-- Fix 4: public.check_calendar_conflicts
CREATE OR REPLACE FUNCTION public.check_calendar_conflicts(
  p_psychologist_id uuid,
  p_start_datetime timestamptz,
  p_end_datetime timestamptz,
  p_exclude_event_id uuid default null
)
RETURNS TABLE(
  event_id uuid,
  event_type calendar_event_type,
  title text,
  start_datetime timestamptz,
  end_datetime timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT id, event_type, title, start_datetime, end_datetime
  FROM public.calendar_events
  WHERE psychologist_id = p_psychologist_id
    AND status NOT IN ('cancelled', 'rescheduled')
    AND (p_exclude_event_id IS NULL OR id != p_exclude_event_id)
    AND start_datetime < p_end_datetime
    AND end_datetime > p_start_datetime;
$$;
-- Fix 5: public.encrypt_token_base64
CREATE OR REPLACE FUNCTION public.encrypt_token_base64(token text, encryption_key text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT encode(extensions.pgp_sym_encrypt(token, encryption_key), 'base64');
$$;
-- Fix 6: public.decrypt_token_base64
CREATE OR REPLACE FUNCTION public.decrypt_token_base64(encrypted_token_base64 text, encryption_key text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT extensions.pgp_sym_decrypt(decode(encrypted_token_base64, 'base64'), encryption_key)::text;
$$;
-- Fix 7: public.update_calendar_updated_at
CREATE OR REPLACE FUNCTION public.update_calendar_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = '';
-- Fix 8: public.validate_weekly_availability_overlaps
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
SET search_path = ''
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
