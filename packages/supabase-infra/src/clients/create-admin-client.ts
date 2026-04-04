/**
 * Create Supabase admin client with service role
 *
 * ⚠️ **SECURITY WARNING**: This client bypasses RLS and has full database access.
 * **NEVER** use this client in browser code or expose service role key to clients.
 *
 * ## Security Considerations
 *
 * This client uses the **service role key** which:
 * - ✅ Bypasses all Row Level Security policies
 * - ✅ Has full CRUD access to all tables
 * - ✅ Can read/write any user's data
 * - ✅ Must be kept secret (server-side only)
 *
 * **NEVER:**
 * - ❌ Use in browser code
 * - ❌ Expose to client-side
 * - ❌ Commit to git
 * - ❌ Log the key
 *
 * ## Usage
 *
 * ```typescript
 * import { createAdminClient } from "@workspace/supabase-infra/clients/admin"
 *
 * // Server-side only
 * const adminClient = createAdminClient()
 *
 * // Full access (bypasses RLS)
 * const { data } = await adminClient.from("profiles").select("*")
 * const allUsers = data // Can see ALL users' data
 * ```
 *
 * ## Use Cases
 *
 * **Appropriate uses:**
 * - ✅ Admin dashboards (with proper auth)
 * - ✅ Background jobs
 * - ✅ Data migration scripts
 * - ✅ Supabase Edge Functions
 * - ✅ Server-side user creation
 *
 * **NOT appropriate:**
 * - ❌ Regular user queries (use regular client)
 * - ❌ Browser code (use browser client)
 * - ❌ Public APIs (use RLS-protected queries)
 *
 * ## Singleton Pattern
 *
 * Uses singleton pattern to avoid creating multiple clients:
 *
 * ```typescript
 * const client1 = createAdminClient()
 * const client2 = createAdminClient()
 *
 * client1 === client2 // true (same instance)
 * ```
 *
 * @returns Typed Supabase client with service role authentication
 * @security Server-side only - never expose to browser
 * @warning Bypasses Row Level Security
 *
 * @module @workspace/supabase-infra/clients/admin
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js"

import { getSupabaseServerEnv } from "@workspace/supabase-infra/env/server"
import type { Database } from "@workspace/supabase-infra/types/database.types"

/**
 * Cached admin client instance (singleton)
 */
let cachedClient: SupabaseClient<Database> | null = null

/**
 * Create or retrieve cached admin client
 *
 * Uses singleton pattern to avoid creating multiple clients.
 * The same client instance is reused across calls.
 *
 * @returns Typed Supabase client with service role
 * @security Uses service role key (bypasses RLS)
 */
export function createAdminClient(): SupabaseClient<Database> {
  if (cachedClient) {
    return cachedClient
  }

  const { SUPABASE_SERVICE_ROLE_KEY: serviceRoleKey, SUPABASE_URL: supabaseUrl } =
    getSupabaseServerEnv()

  cachedClient = createClient<Database>(supabaseUrl, serviceRoleKey, {
    auth: {
      // Disable automatic token refresh (service role doesn't expire)
      autoRefreshToken: false,
      // Don't try to detect session in URL (server-side only)
      detectSessionInUrl: false,
      // Don't persist session (no localStorage in server)
      persistSession: false,
    },
  })

  return cachedClient
}
