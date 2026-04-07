-- Assistant invites: track invite-by-email for assistants (single-use, expiry).
-- Psychologist (practice owner) creates invite via Edge Function (Supabase inviteUserByEmail).
-- Callback matches by email and binds user to practice_memberships on first sign-in.

CREATE TABLE IF NOT EXISTS public.assistant_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  practice_id uuid NOT NULL REFERENCES public.practices(id) ON DELETE CASCADE,
  invited_email text NOT NULL,
  inviter_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS assistant_invites_practice_id_idx ON public.assistant_invites (practice_id);
CREATE INDEX IF NOT EXISTS assistant_invites_invited_email_idx ON public.assistant_invites (invited_email);
CREATE INDEX IF NOT EXISTS assistant_invites_pending_idx ON public.assistant_invites (invited_email, expires_at)
  WHERE accepted_at IS NULL AND revoked_at IS NULL;
COMMENT ON TABLE public.assistant_invites IS 'Invites for assistants; single-use token, expiry; acceptance adds user to practice_memberships.';
ALTER TABLE public.assistant_invites ENABLE ROW LEVEL SECURITY;
-- Practice owner (psychologist) can manage invites for their practice.
CREATE POLICY "assistant_invites_select_owner"
  ON public.assistant_invites
  FOR SELECT
  TO authenticated
  USING (
    practice_id IN (
      SELECT id FROM public.practices WHERE owner_id = auth.uid()
    )
  );
CREATE POLICY "assistant_invites_insert_owner"
  ON public.assistant_invites
  FOR INSERT
  TO authenticated
  WITH CHECK (
    practice_id IN (
      SELECT id FROM public.practices WHERE owner_id = auth.uid()
    )
    AND inviter_user_id = auth.uid()
  );
CREATE POLICY "assistant_invites_update_owner"
  ON public.assistant_invites
  FOR UPDATE
  TO authenticated
  USING (
    practice_id IN (
      SELECT id FROM public.practices WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    practice_id IN (
      SELECT id FROM public.practices WHERE owner_id = auth.uid()
    )
  );
-- RPC: accept assistant invite (call from auth callback when user has no role and has pending invite).
-- Caller must be authenticated and p_user_id = auth.uid().
CREATE OR REPLACE FUNCTION public.accept_assistant_invite(p_user_id uuid, p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite public.assistant_invites;
  v_practice_id uuid;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized');
  END IF;

  SELECT * INTO v_invite
  FROM public.assistant_invites
  WHERE invited_email = lower(trim(p_email))
    AND accepted_at IS NULL
    AND revoked_at IS NULL
    AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_invite.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_pending_invite');
  END IF;

  v_practice_id := v_invite.practice_id;

  INSERT INTO public.practice_memberships (practice_id, user_id, role)
  VALUES (v_practice_id, p_user_id, 'assistant'::public.app_role)
  ON CONFLICT (practice_id, user_id) DO UPDATE SET role = 'assistant'::public.app_role, updated_at = now();

  INSERT INTO public.user_roles (user_id, role)
  VALUES (p_user_id, 'assistant'::public.app_role)
  ON CONFLICT (user_id, role) DO NOTHING;

  INSERT INTO public.assistants (id)
  VALUES (p_user_id)
  ON CONFLICT (id) DO NOTHING;

  UPDATE public.assistant_invites
  SET accepted_at = now(), updated_at = now()
  WHERE id = v_invite.id;

  RETURN jsonb_build_object('success', true, 'practice_id', v_practice_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.accept_assistant_invite(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_assistant_invite(uuid, text) TO service_role;
