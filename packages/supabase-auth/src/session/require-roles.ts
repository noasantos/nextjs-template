import "server-only"
import { redirect } from "next/navigation"

import { getRequestUrl } from "@workspace/supabase-auth/server/get-request-url"
import { getAccess } from "@workspace/supabase-auth/session/get-access"
import { getClaims, type JWTClaims } from "@workspace/supabase-auth/session/get-claims"
import { buildAuthContinueUrl } from "@workspace/supabase-auth/shared/app-destination"
import { buildAuthSignInUrl } from "@workspace/supabase-auth/shared/auth-redirect"
import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"

type RequireRolesOptions = {
  anyOf: readonly AuthRole[]
  redirectTo?: string
}

async function requireRoles({ anyOf, redirectTo }: RequireRolesOptions): Promise<JWTClaims> {
  const claims = await getClaims()
  const safeRedirectTo = redirectTo ?? (await getRequestUrl()) ?? undefined

  if (!claims?.sub) {
    redirect(buildAuthSignInUrl(safeRedirectTo))
  }

  const { roles: userRoles } = await getAccess(claims)

  if (anyOf.some((role) => userRoles.includes(role))) {
    return claims
  }

  if (!anyOf.some((role) => userRoles.includes(role))) {
    redirect(buildAuthContinueUrl(safeRedirectTo))
  }

  return claims
}

export { requireRoles, type RequireRolesOptions }
