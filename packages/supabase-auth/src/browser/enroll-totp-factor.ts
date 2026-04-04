import type { AuthMFAEnrollTOTPResponse } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

type EnrollTotpFactorInput = {
  friendlyName?: string
}

async function enrollTotpFactor({
  friendlyName,
}: EnrollTotpFactorInput = {}): Promise<AuthMFAEnrollTOTPResponse> {
  const supabase = createBrowserAuthClient()

  const enrollArgs = {
    factorType: "totp" as const,
    ...(friendlyName && { friendlyName }),
  }
  // @type-escape: BOUNDARY — Supabase MFA enroll optional spread args; tracked: https://github.com/supabase/supabase-js
  return supabase.auth.mfa.enroll(enrollArgs as never)
}

export { enrollTotpFactor, type EnrollTotpFactorInput }
