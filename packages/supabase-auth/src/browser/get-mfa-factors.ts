import type { AuthMFAListFactorsResponse } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

async function getMfaFactors(): Promise<AuthMFAListFactorsResponse> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.mfa.listFactors()
}

export { getMfaFactors }
