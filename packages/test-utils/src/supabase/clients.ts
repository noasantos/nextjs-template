import { createClient } from "@supabase/supabase-js"

import type { Database } from "@workspace/supabase-infra/types/database"
import { ensureSupabaseTestEnv, getSupabaseTestEnv } from "@workspace/test-utils/supabase/env"

async function createAnonTestClient() {
  await ensureSupabaseTestEnv()

  const { supabasePublishableKey, supabaseUrl } = getSupabaseTestEnv()

  return createClient<Database>(supabaseUrl, supabasePublishableKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  })
}

async function createServiceRoleTestClient() {
  await ensureSupabaseTestEnv()

  const { serviceRoleKey, supabaseUrl } = getSupabaseTestEnv()

  return createClient<Database>(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  })
}

export { createAnonTestClient, createServiceRoleTestClient }
