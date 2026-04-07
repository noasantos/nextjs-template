BEGIN;
-- Billing orchestration metadata on session details
ALTER TABLE public.clinical_session_details
  ADD COLUMN IF NOT EXISTS billing_next_attempt_at timestamptz,
  ADD COLUMN IF NOT EXISTS billing_attempt_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS billing_last_attempt_at timestamptz,
  ADD COLUMN IF NOT EXISTS billing_last_error text;
CREATE INDEX IF NOT EXISTS idx_clinical_session_details_billing_queue
  ON public.clinical_session_details (billing_status, billing_next_attempt_at, clinical_session_id)
  WHERE clinical_session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_clinical_sessions_start_time
  ON public.clinical_sessions (start_time);
-- Dead-letter for repeated billing failures
CREATE TABLE IF NOT EXISTS public.session_billing_dead_letter (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.clinical_sessions(id) ON DELETE CASCADE,
  psychologist_id uuid NOT NULL REFERENCES public.psychologists(id) ON DELETE CASCADE,
  error_message text NOT NULL,
  context jsonb NOT NULL DEFAULT '{}'::jsonb,
  attempts integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_session_billing_dead_letter_open
  ON public.session_billing_dead_letter (session_id)
  WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_session_billing_dead_letter_psychologist
  ON public.session_billing_dead_letter (psychologist_id, created_at DESC);
ALTER TABLE public.session_billing_dead_letter ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'session_billing_dead_letter'
      AND policyname = 'session_billing_dead_letter_owner_access'
  ) THEN
    CREATE POLICY "session_billing_dead_letter_owner_access"
    ON public.session_billing_dead_letter
    FOR ALL
    TO authenticated
    USING (psychologist_id = auth.uid())
    WITH CHECK (psychologist_id = auth.uid());
  END IF;
END;
$$;
COMMIT;
