import type { ClaimsLike } from "@workspace/supabase-auth/shared/get-user-roles-from-claims"
import {
  isPermission,
  type Permission,
} from "@workspace/supabase-auth/shared/permission"

function toPermissions(value: unknown): Permission[] {
  if (typeof value === "string") {
    return isPermission(value) ? [value] : []
  }

  if (!Array.isArray(value)) {
    return []
  }

  return value.filter(
    (permission, index): permission is Permission =>
      typeof permission === "string" &&
      isPermission(permission) &&
      value.indexOf(permission) === index
  )
}

function getUserPermissionsFromClaims(claims: ClaimsLike): Permission[] {
  const permissions = [
    ...toPermissions(claims?.app_metadata?.permissions),
    ...toPermissions(claims?.user_metadata?.permissions),
  ]

  return permissions.filter(
    (permission, index) => permissions.indexOf(permission) === index
  )
}

export { getUserPermissionsFromClaims }
