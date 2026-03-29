import "server-only"

import type { AuthSession } from "@supabase/supabase-js"

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"

async function getSession(): Promise<AuthSession | null> {
  try {
    const supabase = await createServerAuthClient()
    const { data } = await supabase.auth.getSession()

    return data.session ?? null
  } catch {
    return null
  }
}

export { getSession }
