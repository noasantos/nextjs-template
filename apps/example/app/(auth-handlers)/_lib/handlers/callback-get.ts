import { NextResponse, type NextRequest } from "next/server"

import {
  createServerObservabilityContext,
  logServerEvent,
  withServerObservabilityContext,
} from "@workspace/logging/server"
import { exchangeCodeForSession } from "@workspace/supabase-auth/server/exchange-code-for-session"
import { protectSensitiveAuthRoute } from "@workspace/supabase-auth/server/sensitive-route-protection"
import { buildAuthContinueUrl } from "@workspace/supabase-auth/shared/app-destination"
import { getSafeRedirectTo } from "@workspace/supabase-auth/shared/auth-redirect"
import { authCallbackSearchParamsSchema } from "@workspace/supabase-auth/shared/auth-route-input.schema"

export async function callbackGet(request: NextRequest) {
  const requestPath = request.nextUrl?.pathname ?? new URL(request.url).pathname
  const context = await createServerObservabilityContext({
    headers: request.headers,
    requestPath: request.url,
  })

  return withServerObservabilityContext(context, async () => {
    const startedAt = Date.now()
    const requestUrl = new URL(request.url)
    const protection = await protectSensitiveAuthRoute({
      headers: request.headers,
      key: "auth_callback",
    })

    if (!protection.ok) {
      const isMisconfigured = protection.reason === "abuse_protection_required"
      const httpStatus = isMisconfigured ? 503 : 429

      await logServerEvent({
        component: "auth.callback",
        eventFamily: "security.audit",
        eventName: isMisconfigured
          ? "callback_abuse_protection_required"
          : "callback_rate_limited",
        httpStatus,
        metadata: {
          failure_phase: "abuse_protection",
          protection_reason: protection.reason,
          retry_after_seconds: protection.retryAfterSeconds,
        },
        operation: "exchange_code_for_session",
        operationType: "auth",
        outcome: "failure",
        persist: true,
        requestPath,
        service: "auth",
      })

      return new NextResponse(
        isMisconfigured
          ? "Auth abuse protection is not configured for this environment"
          : "Too many requests",
        {
          headers: {
            "Retry-After": String(protection.retryAfterSeconds),
          },
          status: httpStatus,
        }
      )
    }

    const parsed = authCallbackSearchParamsSchema.safeParse({
      code: requestUrl.searchParams.get("code"),
      redirectTo: requestUrl.searchParams.get("redirect_to"),
    })

    if (!parsed.success) {
      await logServerEvent({
        component: "auth.callback",
        eventFamily: "auth.flow",
        eventName: "callback_missing_code",
        httpStatus: 302,
        metadata: {
          failure_phase: "parse",
        },
        operation: "exchange_code_for_session",
        operationType: "auth",
        outcome: "failure",
        persist: true,
        requestPath,
        service: "auth",
      })
      return NextResponse.redirect(
        new URL("/?auth=callback_missing_code", requestUrl.origin)
      )
    }

    const redirectTo = getSafeRedirectTo(parsed.data.redirectTo ?? null)
    const result = await exchangeCodeForSession(parsed.data.code)

    if (result.error) {
      await logServerEvent({
        component: "auth.callback",
        durationMs: Date.now() - startedAt,
        error: result.error,
        eventFamily: "auth.flow",
        eventName: "callback_exchange_failed",
        httpStatus: 302,
        metadata: {
          failure_phase: "gotrue",
        },
        operation: "exchange_code_for_session",
        operationType: "auth",
        outcome: "failure",
        persist: true,
        requestPath,
        service: "auth",
      })
      return NextResponse.redirect(
        new URL("/?auth=callback_error", requestUrl.origin)
      )
    }

    await logServerEvent({
      component: "auth.callback",
      durationMs: Date.now() - startedAt,
      eventFamily: "auth.flow",
      eventName: "callback_exchange_succeeded",
      httpStatus: 302,
      operation: "exchange_code_for_session",
      operationType: "auth",
      outcome: "success",
      persist: true,
      requestPath,
      service: "auth",
    })

    return NextResponse.redirect(buildAuthContinueUrl(redirectTo))
  })
}
