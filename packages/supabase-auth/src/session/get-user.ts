/**
 * Get authenticated user from Supabase Auth
 *
 * ⚠️ **PERFORMANCE WARNING**: This makes a DB call.
 * Use {@link getClaims} for simple auth checks.
 *
 * ## When to Use getUser()
 *
 * **Use this function when you need:**
 * - ✅ Full user profile with metadata
 * - ✅ Email confirmation status
 * - ✅ Last sign-in timestamp
 * - ✅ Phone number
 * - ✅ Avatar URL from metadata
 *
 * **Do NOT use when:**
 * - ❌ Simple auth checks (use {@link getClaims})
 * - ❌ Getting user ID only (use {@link getClaims})
 * - ❌ Checking role (use {@link getClaims})
 * - ❌ Performance-critical paths
 *
 * ## Performance Comparison
 *
 * ```typescript
 * // ✅ FAST - JWKS cached (0 network calls after first)
 * const claims = await getClaims()
 * const userId = claims.sub
 *
 * // ⚠️ SLOWER - DB call every time
 * const user = await getUser()
 * const userId = user.id
 * ```
 *
 * ## Usage
 *
 * ```typescript
 * import { getUser } from "@workspace/supabase-auth/session"
 *
 * export default async function ProfilePage() {
 *   const user = await getUser()
 *
 *   if (!user) {
 *     redirect("/login")
 *   }
 *
 *   return (
 *     <div>
 *       <h1>Welcome, {user.email}</h1>
 *       <p>Last sign in: {user.last_sign_in_at}</p>
 *     </div>
 *   )
 * }
 * ```
 *
 * @returns Auth user or null if not authenticated
 * @performance Makes DB call - use getClaims() for simple checks
 * @see {@link getClaims} - Faster alternative for auth checks
 *
 * @module @workspace/supabase-auth/session/get-user
 */
import "server-only"
import type { User } from "@supabase/supabase-js"
import { cache } from "react"

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"

/**
 * Get and cache authenticated user
 *
 * Uses React cache() for request-level deduplication.
 * Makes a DB call to fetch full user profile.
 *
 * @returns Promise resolving to User or null
 */
export const getUser = cache(async (): Promise<User | null> => {
  try {
    const supabase = await createServerAuthClient()
    const { data } = await supabase.auth.getUser()

    return data.user ?? null
  } catch {
    // Auth errors return null - let caller handle unauthorized
    return null
  }
})
