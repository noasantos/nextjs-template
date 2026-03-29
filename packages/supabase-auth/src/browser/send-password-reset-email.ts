import type { AuthError } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"
import { buildAuthResetPasswordUrl } from "@workspace/supabase-auth/shared/auth-redirect"

type SendPasswordResetEmailInput = {
  email: string
  redirectTo?: string
}

async function sendPasswordResetEmail({
  email,
  redirectTo,
}: SendPasswordResetEmailInput): Promise<{ error: AuthError | null }> {
  const supabase = createBrowserAuthClient()

  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: buildAuthResetPasswordUrl(redirectTo),
  })

  return { error }
}

export { sendPasswordResetEmail, type SendPasswordResetEmailInput }
