import type { ClaimsLike } from "@workspace/supabase-auth/shared/get-user-roles-from-claims"
import { getUserPermissionsFromClaims } from "@workspace/supabase-auth/shared/get-user-permissions-from-claims"
import { getUserRolesFromClaims } from "@workspace/supabase-auth/shared/get-user-roles-from-claims"

type AccessFromClaims = {
  accessVersion: number | null
  permissions: ReturnType<typeof getUserPermissionsFromClaims>
  roles: ReturnType<typeof getUserRolesFromClaims>
  subscription: Record<string, unknown>
}

function getAccessVersionFromClaims(claims: ClaimsLike) {
  const value = claims?.app_metadata?.access_version

  if (typeof value === "number" && Number.isFinite(value)) {
    return value
  }

  if (typeof value === "string") {
    const parsed = Number.parseInt(value, 10)
    return Number.isFinite(parsed) ? parsed : null
  }

  return null
}

function getSubscriptionFromClaims(
  claims: ClaimsLike
): Record<string, unknown> {
  const raw = claims?.app_metadata?.subscription

  if (raw !== null && typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>
  }

  return {}
}

function getAccessFromClaims(claims: ClaimsLike): AccessFromClaims {
  return {
    accessVersion: getAccessVersionFromClaims(claims),
    permissions: getUserPermissionsFromClaims(claims),
    roles: getUserRolesFromClaims(claims),
    subscription: getSubscriptionFromClaims(claims),
  }
}

export {
  getAccessFromClaims,
  getAccessVersionFromClaims,
  getSubscriptionFromClaims,
  type AccessFromClaims,
}
