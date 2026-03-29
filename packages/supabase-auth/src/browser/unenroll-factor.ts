import type { AuthMFAUnenrollResponse } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

type UnenrollFactorInput = {
  factorId: string
}

async function unenrollFactor({
  factorId,
}: UnenrollFactorInput): Promise<AuthMFAUnenrollResponse> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.mfa.unenroll({
    factorId,
  })
}

export { unenrollFactor, type UnenrollFactorInput }
