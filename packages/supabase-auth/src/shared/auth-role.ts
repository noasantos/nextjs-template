import {
  AUTH_PRIVILEGED_ROLE,
  AUTH_ROLE_ALIASES,
  AUTH_ROLES,
  type AuthRole,
} from "@workspace/auth-config/roles"

export { AUTH_ROLES, AUTH_ROLE_LABELS, type AuthRole } from "@workspace/auth-config/roles"

/**
 * Normalises a raw string (e.g. from a JWT claim) to a canonical `AuthRole`.
 * Applies the alias map defined in `@workspace/auth-config/roles` before
 * falling back to an exact match against `AUTH_ROLES`.
 */
function normalizeAuthRole(value: string): AuthRole | null {
  const aliased = AUTH_ROLE_ALIASES[value]
  if (aliased !== undefined) {
    return aliased
  }

  return AUTH_ROLES.includes(value as AuthRole) ? (value as AuthRole) : null
}

function isAuthRole(value: string): value is AuthRole {
  return normalizeAuthRole(value) !== null
}

/**
 * Users with the privileged role (defined in `@workspace/auth-config/roles`)
 * receive every app role in DB/JWT (canonical order).
 */
function expandRolesForAdmin(roles: readonly AuthRole[]): AuthRole[] {
  return roles.includes(AUTH_PRIVILEGED_ROLE) ? [...AUTH_ROLES] : [...roles]
}

export { expandRolesForAdmin, isAuthRole, normalizeAuthRole }
