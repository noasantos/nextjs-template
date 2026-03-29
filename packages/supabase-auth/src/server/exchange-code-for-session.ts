import "server-only"

import type { AuthTokenResponse } from "@supabase/supabase-js"

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"

async function exchangeCodeForSession(
  code: string
): Promise<AuthTokenResponse> {
  const supabase = await createServerAuthClient()

  return supabase.auth.exchangeCodeForSession(code)
}

export { exchangeCodeForSession }
