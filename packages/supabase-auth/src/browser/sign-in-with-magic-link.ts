import type { AuthOtpResponse } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"
import { getSafeRedirectTo } from "@workspace/supabase-auth/shared/auth-redirect"

type SignInWithMagicLinkInput = {
  email: string
  redirectTo?: string
}

async function signInWithMagicLink({
  email,
  redirectTo,
}: SignInWithMagicLinkInput): Promise<AuthOtpResponse> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: getSafeRedirectTo(redirectTo),
      shouldCreateUser: false,
    },
  })
}

export { signInWithMagicLink, type SignInWithMagicLinkInput }
