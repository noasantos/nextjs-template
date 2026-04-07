BEGIN;
-- ============================================================================
-- A) Fix multiple permissive policies
-- ============================================================================

-- Keep only one SELECT path for authenticated on google_sync_logs.
DO $$
BEGIN
  IF to_regclass('public.google_sync_logs') IS NOT NULL THEN
    DROP POLICY IF EXISTS "Psychologists can view own sync logs" ON public.google_sync_logs;
  END IF;
END;
$$;
-- Make service-role access explicit (non-PUBLIC) so it does not overlap
-- with authenticated/anon policies.
DO $$
BEGIN
  IF to_regclass('public.reference_values') IS NOT NULL THEN
    DROP POLICY IF EXISTS reference_values_service_role_all ON public.reference_values;
    CREATE POLICY reference_values_service_role_all
    ON public.reference_values
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END;
$$;
DO $$
BEGIN
  IF to_regclass('public.roles') IS NOT NULL THEN
    DROP POLICY IF EXISTS roles_service_role_all ON public.roles;
    CREATE POLICY roles_service_role_all
    ON public.roles
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END;
$$;
DO $$
BEGIN
  IF to_regclass('public.session_types') IS NOT NULL THEN
    DROP POLICY IF EXISTS session_types_service_role_all ON public.session_types;
    CREATE POLICY session_types_service_role_all
    ON public.session_types
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END;
$$;
DO $$
BEGIN
  IF to_regclass('public.psychologist_subscriptions') IS NOT NULL THEN
    DROP POLICY IF EXISTS psychologist_subscriptions_service_role_all ON public.psychologist_subscriptions;
    CREATE POLICY psychologist_subscriptions_service_role_all
    ON public.psychologist_subscriptions
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
  END IF;
END;
$$;
-- ============================================================================
-- B) Targeted FK index fix (idempotent, no mass index generation)
-- ============================================================================

DO $$
DECLARE
  assistant_attnum smallint;
  has_covering_index boolean;
BEGIN
  IF to_regclass('public.psychologist_assistants') IS NOT NULL THEN
    SELECT a.attnum
    INTO assistant_attnum
    FROM pg_attribute a
    WHERE a.attrelid = 'public.psychologist_assistants'::regclass
      AND a.attname = 'assistant_id'
      AND NOT a.attisdropped;

    IF assistant_attnum IS NOT NULL THEN
      SELECT EXISTS (
        SELECT 1
        FROM pg_index i
        WHERE i.indrelid = 'public.psychologist_assistants'::regclass
          AND i.indisvalid
          AND i.indisready
          AND (string_to_array(i.indkey::text, ' ')::smallint[])[1:1] = ARRAY[assistant_attnum]::smallint[]
      )
      INTO has_covering_index;

      IF NOT has_covering_index THEN
        CREATE INDEX IF NOT EXISTS idx_psychologist_assistants_assistant_id
          ON public.psychologist_assistants (assistant_id);
      END IF;
    END IF;
  END IF;
END;
$$;
COMMIT;
