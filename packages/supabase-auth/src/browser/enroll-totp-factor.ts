import type { AuthMFAEnrollTOTPResponse } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

type EnrollTotpFactorInput = {
  friendlyName?: string
}

async function enrollTotpFactor({
  friendlyName,
}: EnrollTotpFactorInput = {}): Promise<AuthMFAEnrollTOTPResponse> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.mfa.enroll({
    factorType: "totp",
    friendlyName,
  })
}

export { enrollTotpFactor, type EnrollTotpFactorInput }
