import "server-only"
import { redirect } from "next/navigation"

import { getRequestUrl } from "@workspace/supabase-auth/server/get-request-url"
import { getAccess } from "@workspace/supabase-auth/session/get-access"
import { getClaims, type JWTClaims } from "@workspace/supabase-auth/session/get-claims"
import {
  buildAuthAccessDeniedUrl,
  buildAuthSignInUrl,
} from "@workspace/supabase-auth/shared/auth-redirect"
import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"
import type { AccessFromClaims } from "@workspace/supabase-auth/shared/get-access-from-claims"
import type { Permission } from "@workspace/supabase-auth/shared/permission"

type RequireAccessOptions = {
  allOfPermissions?: readonly Permission[]
  anyOfPermissions?: readonly Permission[]
  anyOfRoles?: readonly AuthRole[]
  redirectTo?: string
}

function satisfiesAccess(
  access: AccessFromClaims,
  { allOfPermissions, anyOfPermissions, anyOfRoles }: Omit<RequireAccessOptions, "redirectTo">
) {
  const matchesRoles = !anyOfRoles || anyOfRoles.some((role) => access.roles.includes(role))
  const matchesAnyPermissions =
    !anyOfPermissions ||
    anyOfPermissions.some((permission) => access.permissions.includes(permission))
  const matchesAllPermissions =
    !allOfPermissions ||
    allOfPermissions.every((permission) => access.permissions.includes(permission))

  return matchesRoles && matchesAnyPermissions && matchesAllPermissions
}

async function requireAccess(options: RequireAccessOptions): Promise<JWTClaims> {
  const claims = await getClaims()
  const safeRedirectTo = options.redirectTo ?? (await getRequestUrl()) ?? undefined

  if (!claims?.sub) {
    redirect(buildAuthSignInUrl(safeRedirectTo))
  }

  const access = await getAccess(claims)
  if (satisfiesAccess(access, options)) {
    return claims
  }

  const required = [
    ...(options.anyOfRoles ?? []),
    ...(options.anyOfPermissions ?? []),
    ...(options.allOfPermissions ?? []),
  ]

  redirect(buildAuthAccessDeniedUrl(safeRedirectTo, required))
}

export { requireAccess, type RequireAccessOptions }
