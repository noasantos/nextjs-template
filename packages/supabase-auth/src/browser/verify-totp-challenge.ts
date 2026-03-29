import type { AuthMFAVerifyResponse } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

type VerifyTotpChallengeInput = {
  code: string
  factorId: string
}

async function verifyTotpChallenge({
  code,
  factorId,
}: VerifyTotpChallengeInput): Promise<AuthMFAVerifyResponse> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.mfa.challengeAndVerify({
    code,
    factorId,
  })
}

export { verifyTotpChallenge, type VerifyTotpChallengeInput }
