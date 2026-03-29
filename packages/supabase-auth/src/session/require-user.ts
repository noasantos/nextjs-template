import "server-only"

import type { JwtPayload } from "@supabase/supabase-js"
import { redirect } from "next/navigation"

import { getClaims } from "@workspace/supabase-auth/session/get-claims"
import { getRequestUrl } from "@workspace/supabase-auth/server/get-request-url"
import { buildAuthSignInUrl } from "@workspace/supabase-auth/shared/auth-redirect"

type RequireUserOptions = {
  redirectTo?: string
}

async function requireUser({
  redirectTo,
}: RequireUserOptions = {}): Promise<JwtPayload> {
  const claims = await getClaims()

  if (!claims?.sub) {
    redirect(
      buildAuthSignInUrl(redirectTo ?? (await getRequestUrl()) ?? undefined)
    )
  }

  return claims
}

export { requireUser, type RequireUserOptions }
