import "server-only"

import type { JwtPayload } from "@supabase/supabase-js"

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"
import { getClaims } from "@workspace/supabase-auth/session/get-claims"
import {
  isAuthRole,
  type AuthRole,
} from "@workspace/supabase-auth/shared/auth-role"
import {
  getAccessFromClaims,
  type AccessFromClaims,
} from "@workspace/supabase-auth/shared/get-access-from-claims"
import {
  isPermission,
  type Permission,
} from "@workspace/supabase-auth/shared/permission"

function parseRolesFromRpc(value: unknown): AuthRole[] {
  if (!Array.isArray(value)) {
    return []
  }

  return value.filter(
    (role, index): role is AuthRole =>
      typeof role === "string" &&
      isAuthRole(role) &&
      value.indexOf(role) === index
  )
}

function parsePermissionsFromRpc(value: unknown): Permission[] {
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

function parseSubscriptionFromRpc(value: unknown): Record<string, unknown> {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>
  }

  return {}
}

async function loadAccessFromDb(
  claims: JwtPayload | null
): Promise<AccessFromClaims | null> {
  if (!claims?.sub) {
    return null
  }

  try {
    const supabase = await createServerAuthClient()
    const { data, error } = await supabase.rpc("get_my_access_payload")

    if (error || !data?.[0]) {
      return null
    }

    const row = data[0]
    return {
      accessVersion:
        typeof row.access_version === "number" ? row.access_version : null,
      permissions: parsePermissionsFromRpc(row.permissions),
      roles: parseRolesFromRpc(row.roles),
      subscription: parseSubscriptionFromRpc(row.subscription),
    }
  } catch {
    return null
  }
}

/**
 * Resolves access from JWT claims, optionally merging Postgres-backed payload
 * from `get_my_access_payload` (roles, permissions, subscription, access_version).
 * When the JWT already lists roles, DB permissions are unioned with JWT claims;
 * subscription and access_version prefer the DB snapshot when available.
 */
async function getAccess(
  claims?: JwtPayload | null
): Promise<AccessFromClaims> {
  const resolvedClaims = claims ?? (await getClaims())
  const fromClaims = getAccessFromClaims(resolvedClaims)

  if (fromClaims.roles.length === 0) {
    const fromDb = await loadAccessFromDb(resolvedClaims)
    return fromDb ?? fromClaims
  }

  const fromDb = await loadAccessFromDb(resolvedClaims)
  if (!fromDb) {
    return fromClaims
  }

  const permissions = Array.from(
    new Set([...fromClaims.permissions, ...fromDb.permissions])
  )

  return {
    accessVersion: fromDb.accessVersion ?? fromClaims.accessVersion,
    permissions,
    roles: fromClaims.roles,
    subscription: fromDb.subscription,
  }
}

export { getAccess }
