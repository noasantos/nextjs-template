import { createBrowserClient } from "@supabase/ssr"

import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import type { Database } from "@workspace/supabase-infra/types/database"
import type { TypedSupabaseClient } from "@workspace/supabase-infra/types/supabase"
import { getSupabaseCookieOptions } from "@workspace/supabase-auth/shared/get-supabase-cookie-options"

let browserClient: TypedSupabaseClient | undefined

function createBrowserAuthClient(): TypedSupabaseClient {
  if (browserClient) {
    return browserClient
  }

  const { supabasePublishableKey, supabaseUrl } = getSupabasePublicEnv()

  browserClient = createBrowserClient<Database>(
    supabaseUrl,
    supabasePublishableKey,
    {
      cookieOptions: getSupabaseCookieOptions(),
    }
  )

  return browserClient
}

export { createBrowserAuthClient }
