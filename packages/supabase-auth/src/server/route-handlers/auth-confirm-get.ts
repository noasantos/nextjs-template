import "server-only"
import { NextResponse, type NextRequest } from "next/server"

import {
  createServerObservabilityContext,
  logServerEvent,
  withServerObservabilityContext,
} from "@workspace/logging/server"
import { protectSensitiveAuthRoute } from "@workspace/supabase-auth/server/sensitive-route-protection"
import { verifyOtp } from "@workspace/supabase-auth/server/verify-otp"
import { buildAuthContinueUrl } from "@workspace/supabase-auth/shared/app-destination"
import { getSafeRedirectTo } from "@workspace/supabase-auth/shared/auth-redirect"
import { authConfirmSearchParamsSchema } from "@workspace/supabase-auth/shared/auth-route-input.schema"

export async function authConfirmGet(request: NextRequest) {
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
      key: "auth_confirm",
    })

    if (!protection.ok) {
      const isMisconfigured = protection.reason === "abuse_protection_required"
      const httpStatus = isMisconfigured ? 503 : 429

      await logServerEvent({
        component: "auth.confirm",
        eventFamily: "security.audit",
        eventName: isMisconfigured ? "confirm_abuse_protection_required" : "confirm_rate_limited",
        httpStatus,
        metadata: {
          failure_phase: "abuse_protection",
          protection_reason: protection.reason,
          retry_after_seconds: protection.retryAfterSeconds,
        },
        operation: "verify_otp",
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

    const parsed = authConfirmSearchParamsSchema.safeParse({
      redirectTo: requestUrl.searchParams.get("redirect_to"),
      tokenHash: requestUrl.searchParams.get("token_hash"),
      type: requestUrl.searchParams.get("type"),
    })

    if (!parsed.success) {
      await logServerEvent({
        component: "auth.confirm",
        eventFamily: "auth.flow",
        eventName: "confirm_missing_token",
        httpStatus: 302,
        metadata: {
          failure_phase: "parse",
        },
        operation: "verify_otp",
        operationType: "auth",
        outcome: "failure",
        persist: true,
        requestPath,
        service: "auth",
      })
      return NextResponse.redirect(new URL("/?auth=confirm_missing_token", requestUrl.origin))
    }

    const redirectTo = getSafeRedirectTo(parsed.data.redirectTo ?? null)
    const result = await verifyOtp({
      tokenHash: parsed.data.tokenHash,
      type: parsed.data.type,
    })

    if (result.error) {
      await logServerEvent({
        component: "auth.confirm",
        durationMs: Date.now() - startedAt,
        error: result.error,
        eventFamily: "auth.flow",
        eventName: "confirm_verify_failed",
        httpStatus: 302,
        metadata: {
          failure_phase: "gotrue",
        },
        operation: "verify_otp",
        operationType: "auth",
        outcome: "failure",
        persist: true,
        requestPath,
        service: "auth",
      })
      return NextResponse.redirect(new URL("/?auth=confirm_error", requestUrl.origin))
    }

    await logServerEvent({
      component: "auth.confirm",
      durationMs: Date.now() - startedAt,
      eventFamily: "auth.flow",
      eventName: "confirm_verify_succeeded",
      httpStatus: 302,
      operation: "verify_otp",
      operationType: "auth",
      outcome: "success",
      persist: true,
      requestPath,
      service: "auth",
    })

    return NextResponse.redirect(buildAuthContinueUrl(redirectTo))
  })
}
