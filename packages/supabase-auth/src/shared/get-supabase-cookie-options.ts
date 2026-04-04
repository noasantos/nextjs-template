/**
 * Create Supabase cookie options
 *
 * Ensures consistent cookie configuration across all auth clients.
 * Cookie settings are optimized for security and cross-subdomain session sharing.
 *
 * Configuration (aligned with `@supabase/ssr` / `cookie` `SerializeOptions`):
 * - **maxAge**: 7 days (604800 seconds)
 * - **SameSite**: "lax" (balance between security and UX)
 * - **Secure**: true in production only
 * - **Domain**: Optional, from COOKIE_DOMAIN env var (omitted when unset so `exactOptionalPropertyTypes` stays valid)
 *
 * Usage:
 * ```typescript
 * import { getSupabaseCookieOptions } from "@workspace/supabase-auth/shared"
 *
 * const cookieOptions = getSupabaseCookieOptions()
 * const supabase = createClient(url, key, { cookieOptions })
 * ```
 *
 * @returns Cookie options for Supabase auth
 * @security Production cookies are secure-only
 *
 * @module @workspace/supabase-auth/shared/get-supabase-cookie-options
 */
import type { CookieOptionsWithName } from "@supabase/ssr"

export function getSupabaseCookieOptions(): CookieOptionsWithName {
  const isProduction = process.env.NODE_ENV === "production"
  const cookieDomain = process.env.COOKIE_DOMAIN

  const base: CookieOptionsWithName = {
    name: "auth-token",
    maxAge: 60 * 60 * 24 * 7, // 7 days (same field as @supabase/ssr DEFAULT_COOKIE_OPTIONS)
    path: "/",
    sameSite: "lax",
    secure: isProduction,
  }

  if (cookieDomain) {
    return { ...base, domain: cookieDomain }
  }

  return base
}
