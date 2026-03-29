import "server-only"

import { createClient } from "@supabase/supabase-js"

import { getSupabaseServerEnv } from "@workspace/supabase-infra/env/server"
import type { Database } from "@workspace/supabase-infra/types/database"

function createAdminClient() {
  const { serviceRoleKey, supabaseUrl } = getSupabaseServerEnv()

  return createClient<Database>(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  })
}

export { createAdminClient }
