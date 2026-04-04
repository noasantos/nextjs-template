import "server-only"
import { logServerEvent } from "@workspace/logging/server"
import { expandRolesForAdmin, type AuthRole } from "@workspace/supabase-auth/shared/auth-role"
import {
  UserAccessDTOSchema,
  type UserAccessDTO,
} from "@workspace/supabase-data/modules/user-access/domain/dto/user-access.dto"
import { createAdminClient } from "@workspace/supabase-infra/clients/admin"

function parseUserAccess(
  userId: string,
  {
    accessVersion,
    permissions,
    roles,
    subscription,
  }: {
    accessVersion: number | null
    permissions: readonly string[]
    roles: readonly string[]
    subscription: Record<string, unknown>
  }
): UserAccessDTO {
  return UserAccessDTOSchema.parse({
    accessVersion,
    permissions,
    roles,
    subscription,
    userId,
  })
}

/**
 * Syncs DB-backed roles via `sync_user_roles`, then refreshes JWT-facing `app_metadata`.
 *
 * Permission overrides and `role_permissions` were removed from the template baseline; effective
 * permissions are enforced in application code (or a future migration) — the hook emits an empty
 * `permissions` array. Subscription and `access_version` come from `profiles` when present.
 */
async function syncUserAccess(userId: string, roles: readonly AuthRole[]): Promise<UserAccessDTO> {
  const startedAt = Date.now()
  const admin = createAdminClient()
  const effectiveRoles = expandRolesForAdmin(roles)

  const syncRolesArgs = {
    p_roles: effectiveRoles,
    p_user_id: userId,
  }
  // @type-escape: BOUNDARY — rpc sync_user_roles args vs generated Database types; tracked: https://github.com/supabase/supabase-js
  const { error: syncDbError } = await admin.rpc("sync_user_roles", syncRolesArgs as never)

  if (syncDbError) {
    await logServerEvent({
      actorId: userId,
      actorType: "service",
      component: "user_access.sync",
      durationMs: Date.now() - startedAt,
      error: syncDbError,
      eventFamily: "privileged.operation",
      eventName: "sync_user_access_rpc_failed",
      metadata: {
        failure_phase: "rpc",
        roles: effectiveRoles,
      },
      operation: "syncUserAccess",
      operationType: "admin",
      outcome: "failure",
      persist: true,
      service: "supabase-data",
    })
    throw syncDbError
  }

  const profileResult = await admin
    .from("profiles")
    .select("access_version, subscription")
    .eq("user_id", userId)
    .maybeSingle()

  if (profileResult.error) {
    await logServerEvent({
      actorId: userId,
      actorType: "service",
      component: "user_access.sync",
      durationMs: Date.now() - startedAt,
      error: profileResult.error,
      eventFamily: "privileged.operation",
      eventName: "sync_user_access_profile_load_failed",
      metadata: {
        failure_phase: "repository",
        roles: effectiveRoles,
      },
      operation: "syncUserAccess",
      operationType: "admin",
      outcome: "failure",
      persist: true,
      service: "supabase-data",
    })
    throw profileResult.error
  }

  const profileData = profileResult.data as {
    access_version: number
    subscription: Record<string, unknown>
  } | null

  const accessVersion =
    typeof profileData?.access_version === "number" ? profileData.access_version : 1
  const subscriptionRaw = profileData?.subscription
  const subscription =
    subscriptionRaw !== null &&
    typeof subscriptionRaw === "object" &&
    !Array.isArray(subscriptionRaw)
      ? (subscriptionRaw as Record<string, unknown>)
      : {}

  const userResult = await admin.auth.admin.getUserById(userId)

  if (userResult.error || !userResult.data.user) {
    await logServerEvent({
      actorId: userId,
      actorType: "service",
      component: "user_access.sync",
      durationMs: Date.now() - startedAt,
      error: userResult.error ?? new Error("Failed to load auth user metadata."),
      eventFamily: "privileged.operation",
      eventName: "sync_user_access_load_user_failed",
      metadata: {
        failure_phase: "gotrue",
        roles: effectiveRoles,
      },
      operation: "syncUserAccess",
      operationType: "admin",
      outcome: "failure",
      persist: true,
      service: "supabase-data",
    })
    throw userResult.error ?? new Error("Failed to load auth user metadata.")
  }

  const currentAppMetadata =
    userResult.data.user.app_metadata && typeof userResult.data.user.app_metadata === "object"
      ? userResult.data.user.app_metadata
      : {}

  const effectivePermissions: string[] = []

  const { error: updateUserError } = await admin.auth.admin.updateUserById(userId, {
    app_metadata: {
      ...currentAppMetadata,
      access_version: accessVersion,
      permissions: effectivePermissions,
      roles: effectiveRoles,
      subscription,
    },
  })

  if (updateUserError) {
    await logServerEvent({
      actorId: userId,
      actorType: "service",
      component: "user_access.sync",
      durationMs: Date.now() - startedAt,
      error: updateUserError,
      eventFamily: "privileged.operation",
      eventName: "sync_user_access_metadata_update_failed",
      metadata: {
        effective_permissions: effectivePermissions,
        failure_phase: "gotrue",
        roles: effectiveRoles,
      },
      operation: "syncUserAccess",
      operationType: "admin",
      outcome: "failure",
      persist: true,
      service: "supabase-data",
    })
    throw updateUserError
  }

  await logServerEvent({
    actorId: userId,
    actorType: "service",
    component: "user_access.sync",
    durationMs: Date.now() - startedAt,
    eventFamily: "security.audit",
    eventName: "sync_user_access_succeeded",
    metadata: {
      effective_permissions: effectivePermissions,
      roles: effectiveRoles,
    },
    operation: "syncUserAccess",
    operationType: "admin",
    outcome: "success",
    persist: true,
    service: "supabase-data",
  })

  return parseUserAccess(userId, {
    accessVersion,
    permissions: effectivePermissions,
    roles: effectiveRoles,
    subscription,
  })
}

export { syncUserAccess }
