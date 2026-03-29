import type { AuthTokenResponsePassword } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

type SignInWithPasswordInput = {
  email: string
  password: string
}

async function signInWithPassword({
  email,
  password,
}: SignInWithPasswordInput): Promise<AuthTokenResponsePassword> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.signInWithPassword({
    email,
    password,
  })
}

export { signInWithPassword, type SignInWithPasswordInput }
