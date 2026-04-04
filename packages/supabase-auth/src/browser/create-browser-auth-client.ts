/**
 * Create browser Supabase auth client
 *
 * Uses singleton pattern to avoid creating multiple clients in browser
 *
 * Usage:
 * ```typescript
 * const supabase = createBrowserAuthClient()
 * const { data } = await supabase.auth.getUser()
 * ```
 *
 * @returns Typed Supabase client for browser authentication
 *
 * @module @workspace/supabase-auth/browser/create-browser-auth-client
 */
import { createBrowserClient } from "@supabase/ssr"

import { getSupabaseCookieOptions } from "@workspace/supabase-auth/shared/get-supabase-cookie-options"
import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import type { Database } from "@workspace/supabase-infra/types/database"
import type { TypedSupabaseClient } from "@workspace/supabase-infra/types/supabase"

let browserClient: TypedSupabaseClient | undefined

export function createBrowserAuthClient(): TypedSupabaseClient {
  if (browserClient) {
    return browserClient
  }

  const env = getSupabasePublicEnv()

  browserClient = createBrowserClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookieOptions: getSupabaseCookieOptions(),
    }
  )

  return browserClient
}
