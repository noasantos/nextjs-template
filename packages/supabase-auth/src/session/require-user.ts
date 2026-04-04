import "server-only"
import { redirect } from "next/navigation"

import { getRequestUrl } from "@workspace/supabase-auth/server/get-request-url"
import { getClaims, type JWTClaims } from "@workspace/supabase-auth/session/get-claims"
import { buildAuthSignInUrl } from "@workspace/supabase-auth/shared/auth-redirect"

type RequireUserOptions = {
  redirectTo?: string
}

async function requireUser({ redirectTo }: RequireUserOptions = {}): Promise<JWTClaims> {
  const claims = await getClaims()

  if (!claims?.sub) {
    redirect(buildAuthSignInUrl(redirectTo ?? (await getRequestUrl()) ?? undefined))
  }

  return claims
}

export { requireUser, type RequireUserOptions }
