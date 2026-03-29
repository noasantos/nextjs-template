import "server-only"

import type { JwtPayload } from "@supabase/supabase-js"
import { unstable_rethrow } from "next/navigation"

import { logServerEvent } from "@workspace/logging/server"
import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"

async function getClaims(): Promise<JwtPayload | null> {
  try {
    const supabase = await createServerAuthClient()
    const { data } = await supabase.auth.getClaims()

    return data?.claims ?? null
  } catch (error) {
    unstable_rethrow(error)
    await logServerEvent({
      component: "supabase_auth.session",
      error,
      eventFamily: "supabase.integration",
      eventName: "claims_lookup_failed",
      metadata: {
        failure_phase: "session_refresh",
      },
      operation: "getClaims",
      operationType: "auth",
      outcome: "failure",
      persist: true,
      service: "supabase-auth",
    })
    return null
  }
}

export { getClaims }
