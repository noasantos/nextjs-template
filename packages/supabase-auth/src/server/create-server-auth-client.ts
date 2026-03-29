import "server-only"

import { createServerClient } from "@supabase/ssr"
import { cookies } from "next/headers"

import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import type { Database } from "@workspace/supabase-infra/types/database"
import type { TypedSupabaseClient } from "@workspace/supabase-infra/types/supabase"
import { getSupabaseCookieOptions } from "@workspace/supabase-auth/shared/get-supabase-cookie-options"

async function createServerAuthClient(): Promise<TypedSupabaseClient> {
  const cookieStore = await cookies()
  const { supabasePublishableKey, supabaseUrl } = getSupabasePublicEnv()

  return createServerClient<Database>(supabaseUrl, supabasePublishableKey, {
    cookieOptions: getSupabaseCookieOptions(),
    cookies: {
      getAll() {
        return cookieStore.getAll()
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, options, value }) => {
            cookieStore.set(name, value, options)
          })
        } catch {
          // Server Components cannot always write cookies. Proxy handles refresh writes.
        }
      },
    },
  })
}

export { createServerAuthClient }
