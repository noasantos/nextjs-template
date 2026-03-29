import type { AuthMFAGetAuthenticatorAssuranceLevelResponse } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

async function getAuthenticatorAssuranceLevel(): Promise<AuthMFAGetAuthenticatorAssuranceLevelResponse> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.mfa.getAuthenticatorAssuranceLevel()
}

export { getAuthenticatorAssuranceLevel }
