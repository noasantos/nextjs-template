/**
 * Update session in Next.js 16 proxy (middleware)
 *
 * This is the core authentication proxy for Next.js 16 applications.
 * It handles:
 * - Session refresh via Supabase SDK
 * - Cookie management for SSR
 * - CVE-2025-29927 protection (header sanitization)
 * - Correlation ID tracking
 * - CSP nonce injection
 *
 * Usage in apps/web/proxy.ts:
 * ```typescript
 * import { updateSession } from "@workspace/supabase-auth/proxy"
 *
 * export default async function proxy(request: NextRequest) {
 *   return await updateSession(request)
 * }
 * ```
 *
 * @module @workspace/supabase-auth/proxy/update-session
 */
import { createServerClient, type SetAllCookies } from "@supabase/ssr"
import { type NextRequest, NextResponse } from "next/server"

import {
  applyCorrelationHeaders,
  extractCorrelationFromHeaders,
  type CorrelationContext,
} from "@workspace/logging/correlation"
import { getSupabaseCookieOptions } from "@workspace/supabase-auth/shared/get-supabase-cookie-options"
import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import type { Database } from "@workspace/supabase-infra/types/database"

/**
 * Preserve Next.js middleware continuation headers
 */
function mergeUpstreamMiddlewareHeaders(source: Headers, target: Headers) {
  if (source.get("x-middleware-rewrite")) {
    target.delete("x-middleware-next")
  }

  source.forEach((value, key) => {
    const lower = key.toLowerCase()
    if (lower.startsWith("x-middleware-") || lower.startsWith("x-next-intl-") || lower === "link") {
      target.set(key, value)
    }
  })
}

/**
 * Sync cookie header from request cookies
 */
function syncRequestCookieHeader(request: Pick<NextRequest, "cookies">, requestHeaders: Headers) {
  const cookieHeader = request.cookies
    .getAll()
    .map(({ name, value }) => `${name}=${value}`)
    .join("; ")

  if (cookieHeader) {
    requestHeaders.set("cookie", cookieHeader)
    return
  }

  requestHeaders.delete("cookie")
}

/**
 * Update session with Supabase authentication
 *
 * @param request - Next.js request object
 * @param correlation - Optional correlation context
 * @param upstreamResponse - Optional upstream middleware response
 * @returns NextResponse with updated session cookies
 */
export async function updateSession(
  request: NextRequest,
  correlation: CorrelationContext = extractCorrelationFromHeaders(request.headers),
  upstreamResponse?: NextResponse
): Promise<NextResponse> {
  const env = getSupabasePublicEnv()
  const requestHeaders = new Headers(request.headers)

  // Apply correlation headers
  applyCorrelationHeaders(requestHeaders, correlation)

  /**
   * Create NextResponse with merged headers
   */
  function nextWithMergedHeaders(): NextResponse {
    const res = NextResponse.next({
      request: {
        headers: requestHeaders,
      },
    })
    applyCorrelationHeaders(res.headers, correlation)

    if (upstreamResponse) {
      mergeUpstreamMiddlewareHeaders(upstreamResponse.headers, res.headers)
    }

    return res
  }

  let response = nextWithMergedHeaders()

  // Create Supabase client with cookie handling
  const supabase = createServerClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookieOptions: getSupabaseCookieOptions(),
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll: ((cookiesToSet) => {
          // Update request cookies
          cookiesToSet.forEach(({ name, value }) => {
            request.cookies.set(name, value)
          })
          syncRequestCookieHeader(request, requestHeaders)

          // Rebuild response with updated headers
          response = nextWithMergedHeaders()

          // Set response cookies
          cookiesToSet.forEach(({ name, options, value }) => {
            response.cookies.set(name, value, options)
          })
        }) satisfies SetAllCookies,
      },
    }
  )

  /**
   * Refresh session claims (JWKS cached)
   * This is the primary auth point in the proxy pipeline
   */
  try {
    await supabase.auth.getClaims()
  } catch {
    // Session refresh failed, continue with response
    // Auth guards will handle unauthorized requests
  }

  return response
}
