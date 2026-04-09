const AUTH_ROLES = ["admin", "user"] as const

type AuthRole = (typeof AUTH_ROLES)[number]

const AUTH_ROLE_LABELS: Record<AuthRole, string> = {
  admin: "Admin",
  user: "User",
}

function isAuthRole(value: string): value is AuthRole {
  return AUTH_ROLES.includes(value as AuthRole)
}

/** Returns the value as an `AuthRole` when valid, otherwise `null`. */
function normalizeAuthRole(value: string): AuthRole | null {
  return isAuthRole(value) ? value : null
}

/** Users with `admin` receive every app role in DB/JWT (canonical order). */
function expandRolesForAdmin(roles: readonly AuthRole[]): AuthRole[] {
  return roles.includes("admin") ? [...AUTH_ROLES] : [...roles]
}

export {
  AUTH_ROLES,
  AUTH_ROLE_LABELS,
  expandRolesForAdmin,
  isAuthRole,
  normalizeAuthRole,
  type AuthRole,
}
