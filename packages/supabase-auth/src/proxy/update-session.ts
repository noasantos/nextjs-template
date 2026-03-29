import { createServerClient } from "@supabase/ssr"
import { type NextRequest, NextResponse } from "next/server"

import {
  applyCorrelationHeaders,
  extractCorrelationFromHeaders,
  type CorrelationContext,
} from "@workspace/logging/correlation"
import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import type { Database } from "@workspace/supabase-infra/types/database"
import { getSupabaseCookieOptions } from "@workspace/supabase-auth/shared/get-supabase-cookie-options"
import { LOG_REQUEST_URL_HEADER } from "@workspace/supabase-auth/shared/request-headers"

function syncRequestCookieHeader(
  request: Pick<NextRequest, "cookies">,
  requestHeaders: Headers
) {
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

/** Headers set by upstream middleware (e.g. next-intl) that must survive Supabase cookie rebuilds. */
function copyPersistedUpstreamHeaders(source: Headers, target: Headers) {
  source.forEach((value, key) => {
    const lower = key.toLowerCase()
    if (lower === "link" || lower.startsWith("x-next-intl-")) {
      target.set(key, value)
    }
  })
}

async function updateSession(
  request: NextRequest,
  correlation: CorrelationContext = extractCorrelationFromHeaders(
    request.headers
  ),
  upstreamResponse?: NextResponse
) {
  const { supabasePublishableKey, supabaseUrl } = getSupabasePublicEnv()
  const requestHeaders = new Headers(request.headers)

  requestHeaders.set(LOG_REQUEST_URL_HEADER, request.nextUrl.toString())
  applyCorrelationHeaders(requestHeaders, correlation)

  function nextWithMergedHeaders(): NextResponse {
    const res = NextResponse.next({
      request: {
        headers: requestHeaders,
      },
    })
    applyCorrelationHeaders(res.headers, correlation)
    if (upstreamResponse) {
      copyPersistedUpstreamHeaders(upstreamResponse.headers, res.headers)
    }
    return res
  }

  let response = nextWithMergedHeaders()

  const supabase = createServerClient<Database>(
    supabaseUrl,
    supabasePublishableKey,
    {
      cookieOptions: getSupabaseCookieOptions(),
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => {
            request.cookies.set(name, value)
          })
          syncRequestCookieHeader(request, requestHeaders)

          response = nextWithMergedHeaders()

          cookiesToSet.forEach(({ name, options, value }) => {
            response.cookies.set(name, value, options)
          })
        },
      },
    }
  )

  try {
    await supabase.auth.getClaims()
  } catch {
    return response
  }

  return response
}

export { updateSession }
