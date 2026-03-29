import type { AuthError } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

async function signOut(): Promise<{ error: AuthError | null }> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.signOut()
}

export { signOut }
