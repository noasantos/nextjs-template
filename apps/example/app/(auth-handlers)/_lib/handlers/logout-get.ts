import { NextResponse, type NextRequest } from "next/server"

import {
  createServerObservabilityContext,
  logServerEvent,
  withServerObservabilityContext,
} from "@workspace/logging/server"
import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"
import { getSafeRedirectTo } from "@workspace/supabase-auth/shared/auth-redirect"
import { authLogoutSearchParamsSchema } from "@workspace/supabase-auth/shared/auth-route-input.schema"

export async function logoutGet(request: NextRequest) {
  const requestPath = request.nextUrl?.pathname ?? new URL(request.url).pathname
  const context = await createServerObservabilityContext({
    headers: request.headers,
    requestPath: request.url,
  })

  return withServerObservabilityContext(context, async () => {
    const startedAt = Date.now()
    const supabase = await createServerAuthClient()
    const requestUrl = new URL(request.url)

    const result = await supabase.auth.signOut()

    if (result.error) {
      await logServerEvent({
        component: "auth.logout",
        durationMs: Date.now() - startedAt,
        error: result.error,
        eventFamily: "auth.flow",
        eventName: "logout_failed",
        httpStatus: 302,
        metadata: {
          failure_phase: "gotrue",
        },
        operation: "sign_out",
        operationType: "auth",
        outcome: "failure",
        persist: true,
        requestPath,
        service: "auth",
      })
    } else {
      await logServerEvent({
        component: "auth.logout",
        durationMs: Date.now() - startedAt,
        eventFamily: "auth.flow",
        eventName: "logout_succeeded",
        httpStatus: 302,
        operation: "sign_out",
        operationType: "auth",
        outcome: "success",
        persist: true,
        requestPath,
        service: "auth",
      })
    }

    const parsed = authLogoutSearchParamsSchema.parse({
      redirectTo: requestUrl.searchParams.get("redirect_to"),
    })

    const redirectTo = getSafeRedirectTo(
      parsed.redirectTo ?? null,
      new URL("/sign-in?auth=signed_out", requestUrl.origin).toString()
    )

    return NextResponse.redirect(redirectTo)
  })
}
