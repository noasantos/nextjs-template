-- ============================================================================
-- Migration: Fix daily consolidation to use correct table and auto-create category
-- ============================================================================

-- Drop old functions
DROP FUNCTION IF EXISTS public.consolidate_daily_charges(UUID, DATE);
DROP FUNCTION IF EXISTS public.recalculate_daily_consolidation_for_charge(UUID);
-- ============================================================================
-- Create daily consolidation function with correct table name
-- ============================================================================

CREATE OR REPLACE FUNCTION public.consolidate_daily_charges(
  p_psychologist_id UUID,
  p_date DATE
)
RETURNS TABLE(
  action TEXT,
  entry_id UUID,
  entry_date DATE,
  amount_cents INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_day_start TIMESTAMPTZ;
  v_day_end TIMESTAMPTZ;
  v_total_cents INTEGER;
  v_entry_id UUID;
  v_category_id UUID;
  v_existing_entry_id UUID;
  v_charge_count INTEGER;
BEGIN
  -- Define day boundaries in UTC
  v_day_start := p_date::TIMESTAMPTZ;
  v_day_end := (p_date + INTERVAL '1 day')::TIMESTAMPTZ;
  
  -- Get or create category ID for daily consolidation
  SELECT id INTO v_category_id
  FROM financial_categories
  WHERE psychologist_id = p_psychologist_id
    AND category_name = 'Consolidação Diária'
  LIMIT 1;
  
  -- Create category if not exists
  IF v_category_id IS NULL THEN
    INSERT INTO financial_categories (
      psychologist_id,
      category_name,
      category_type,
      description,
      color,
      is_default,
      is_active,
      created_at,
      updated_at
    ) VALUES (
      p_psychologist_id,
      'Consolidação Diária',
      'income',
      'Consolidação automática de cobranças pagas por dia',
      '#10B981',
      true,
      true,
      NOW(),
      NOW()
    )
    RETURNING id INTO v_category_id;
  END IF;
  
  -- Count paid charges for sessions on this date
  SELECT 
    COUNT(*),
    COALESCE(SUM(c.price_cents), 0)
  INTO v_charge_count, v_total_cents
  FROM psychologist_client_charges c
  JOIN clinical_sessions s ON s.id = c.session_id
  WHERE c.psychologist_id = p_psychologist_id
    AND c.payment_status = 'paid'
    AND s.start_time >= v_day_start
    AND s.start_time < v_day_end;
  
  -- Check if entry already exists for this date
  -- Also look for entries with NULL category_id (legacy entries)
  SELECT id INTO v_existing_entry_id
  FROM psychologist_financial_entries
  WHERE psychologist_id = p_psychologist_id
    AND type = 'income'
    AND (category_id = v_category_id OR category_id IS NULL)
    AND description LIKE 'Serviços Prestados%'
    AND date_time::date = p_date
  LIMIT 1;
  
  IF v_charge_count = 0 THEN
    -- No paid charges - delete existing entry if present
    IF v_existing_entry_id IS NOT NULL THEN
      DELETE FROM psychologist_financial_entries WHERE id = v_existing_entry_id;
      RETURN QUERY SELECT 'deleted'::TEXT, v_existing_entry_id, p_date, 0;
    END IF;
  ELSIF v_existing_entry_id IS NOT NULL THEN
    -- Entry exists - update amount
    UPDATE psychologist_financial_entries
    SET 
      amount = v_total_cents,
      description = 'Serviços Prestados ' || to_char(p_date, 'DD') || ' ' ||
        CASE extract(month FROM p_date)
          WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
          WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
          WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
          WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
        END,
      updated_at = NOW()
    WHERE id = v_existing_entry_id;
    RETURN QUERY SELECT 'updated'::TEXT, v_existing_entry_id, p_date, v_total_cents;
  ELSE
    -- Create new entry
    INSERT INTO psychologist_financial_entries (
      psychologist_id,
      type,
      category_id,
      amount,
      description,
      date_time,
      created_at,
      updated_at
    ) VALUES (
      p_psychologist_id,
      'income',
      v_category_id,
      v_total_cents,
      'Serviços Prestados ' || to_char(p_date, 'DD') || ' ' ||
        CASE extract(month FROM p_date)
          WHEN 1 THEN 'Jan' WHEN 2 THEN 'Fev' WHEN 3 THEN 'Mar'
          WHEN 4 THEN 'Abr' WHEN 5 THEN 'Mai' WHEN 6 THEN 'Jun'
          WHEN 7 THEN 'Jul' WHEN 8 THEN 'Ago' WHEN 9 THEN 'Set'
          WHEN 10 THEN 'Out' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Dez'
        END,
      p_date::TIMESTAMPTZ,
      NOW(),
      NOW()
    )
    RETURNING id INTO v_entry_id;
    RETURN QUERY SELECT 'created'::TEXT, v_entry_id, p_date, v_total_cents;
  END IF;
END;
$$;
-- ============================================================================
-- Create recalculation function for single charge
-- ============================================================================

CREATE OR REPLACE FUNCTION public.recalculate_daily_consolidation_for_charge(
  p_charge_id UUID
)
RETURNS TABLE(
  action TEXT,
  entry_id UUID,
  entry_date DATE,
  amount_cents INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_psychologist_id UUID;
  v_session_date DATE;
BEGIN
  -- Get charge info
  SELECT 
    c.psychologist_id,
    s.start_time::date
  INTO v_psychologist_id, v_session_date
  FROM psychologist_client_charges c
  JOIN clinical_sessions s ON s.id = c.session_id
  WHERE c.id = p_charge_id;
  
  IF v_psychologist_id IS NULL THEN
    RETURN;
  END IF;
  
  -- Recalculate consolidation for that date
  RETURN QUERY SELECT * FROM consolidate_daily_charges(v_psychologist_id, v_session_date);
END;
$$;
