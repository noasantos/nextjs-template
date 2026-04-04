/**
 * Get authenticated session
 *
 * ⚠️ **DEPRECATED for server auth checks**.
 * Use {@link getClaims} instead - it's faster (JWKS cached).
 *
 * ## Deprecated: Why?
 *
 * This function returns the full session object including:
 * - Access token
 * - Refresh token
 * - Expires at
 * - Provider token
 *
 * For simple auth checks, this is **overkill** and slower than {@link getClaims}.
 *
 * ## When to Use getSession()
 *
 * **Legacy usage only:**
 * - ✅ Need session expiry time
 * - ✅ Need refresh token
 * - ✅ Need provider_token for API calls
 * - ✅ Need token_type
 *
 * **Do NOT use when:**
 * - ❌ Simple auth checks (use {@link getClaims})
 * - ❌ Getting user ID (use {@link getClaims})
 * - ❌ Checking role (use {@link getClaims})
 *
 * ## Migration Guide
 *
 * ```typescript
 * // ❌ OLD - Slow (DB call)
 * const session = await getSession()
 * if (!session) redirect("/login")
 *
 * // ✅ NEW - Fast (JWKS cached)
 * const claims = await getClaims()
 * if (!claims?.sub) redirect("/login")
 * ```
 *
 * ## Usage
 *
 * ```typescript
 * import { getSession } from "@workspace/supabase-auth/session"
 *
 * // Only when you need session details
 * const session = await getSession()
 * if (session) {
 *   // Use expires_at if needed; never log tokens.
 *   void session.expires_at
 * }
 * ```
 *
 * @returns Session or null if not authenticated
 * @deprecated Use getClaims() for auth checks
 * @see {@link getClaims} - Faster alternative
 *
 * @module @workspace/supabase-auth/session/get-session
 */
import "server-only"
import type { Session } from "@supabase/supabase-js"
import { cache } from "react"

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"

/**
 * Get and cache authenticated session
 *
 * Uses React cache() for request-level deduplication.
 * Returns full session object with tokens.
 *
 * @returns Promise resolving to Session or null
 * @deprecated Prefer getClaims() for simple auth checks
 */
export const getSession = cache(async (): Promise<Session | null> => {
  try {
    const supabase = await createServerAuthClient()
    const { data } = await supabase.auth.getSession()

    return data.session ?? null
  } catch {
    // Auth errors return null - let caller handle unauthorized
    return null
  }
})
