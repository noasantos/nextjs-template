import "server-only"

import type { AuthUser } from "@supabase/supabase-js"

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"

async function getUser(): Promise<AuthUser | null> {
  try {
    const supabase = await createServerAuthClient()
    const { data } = await supabase.auth.getUser()

    return data.user ?? null
  } catch {
    return null
  }
}

export { getUser }
