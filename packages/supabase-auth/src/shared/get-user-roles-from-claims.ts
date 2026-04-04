import type { JwtPayload } from "@supabase/supabase-js"

import { isAuthRole, type AuthRole } from "@workspace/supabase-auth/shared/auth-role"

type ClaimsLike = Pick<JwtPayload, "app_metadata" | "user_metadata"> | null | undefined

function toAuthRoles(value: unknown): AuthRole[] {
  if (typeof value === "string") {
    return isAuthRole(value) ? [value] : []
  }

  if (!Array.isArray(value)) {
    return []
  }

  return value.filter(
    (role, index): role is AuthRole =>
      typeof role === "string" && isAuthRole(role) && value.indexOf(role) === index
  )
}

function getUserRolesFromClaims(claims: ClaimsLike): AuthRole[] {
  const roles = [
    ...toAuthRoles(claims?.app_metadata?.roles),
    ...toAuthRoles(claims?.app_metadata?.role),
    ...toAuthRoles(claims?.user_metadata?.roles),
    ...toAuthRoles(claims?.user_metadata?.role),
  ]

  return roles.filter((role, index) => roles.indexOf(role) === index)
}

export { getUserRolesFromClaims, type ClaimsLike }
