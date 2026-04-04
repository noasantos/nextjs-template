/**
 * Create server Supabase auth client
 *
 * This client is used in Server Components and Server Actions.
 * It handles cookies properly for SSR authentication.
 *
 * **Key Features:**
 * - Automatic cookie management for SSR
 * - Handles cookie writes in Server Components
 * - Uses Next.js `cookies()` API
 * - Singleton pattern per request (fluid compute)
 *
 * **Usage in Server Components:**
 * ```typescript
 * import { createServerAuthClient } from "@workspace/supabase-auth/server"
 *
 * export default async function Page() {
 *   const supabase = await createServerAuthClient()
 *   const { data } = await supabase.auth.getUser()
 * }
 * ```
 *
 * **Usage in Server Actions:**
 * ```typescript
 * "use server"
 *
 * export async function myAction() {
 *   const supabase = await createServerAuthClient()
 *   const { data } = await supabase.auth.getClaims()
 * }
 * ```
 *
 * @returns Typed Supabase client for server authentication
 * @security Server-side only - never expose to browser
 *
 * @module @workspace/supabase-auth/server/create-server-auth-client
 */
import { createServerClient, type SetAllCookies } from "@supabase/ssr"
import { cookies } from "next/headers"

import { getSupabaseCookieOptions } from "@workspace/supabase-auth/shared/get-supabase-cookie-options"
import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import type { Database } from "@workspace/supabase-infra/types/database"
import type { TypedSupabaseClient } from "@workspace/supabase-infra/types/supabase"

/**
 * Create or retrieve server auth client
 *
 * Creates a new client for each request (fluid compute pattern).
 * This prevents auth state leakage between requests.
 *
 * @returns Promise resolving to typed Supabase client
 */
export async function createServerAuthClient(): Promise<TypedSupabaseClient> {
  const cookieStore = await cookies()
  const env = getSupabasePublicEnv()

  return createServerClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookieOptions: getSupabaseCookieOptions(),
      cookies: {
        /**
         * Read all cookies from request
         */
        getAll() {
          return cookieStore.getAll()
        },
        /**
         * Write cookies to response
         *
         * Handles cookie writes in Server Components where
         * we can't directly modify the response headers.
         */
        setAll: ((cookiesToSet) => {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options)
          })
        }) satisfies SetAllCookies,
      },
    }
  )
}
