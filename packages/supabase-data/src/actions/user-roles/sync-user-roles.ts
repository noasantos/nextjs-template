import "server-only"
import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"
import { syncUserAccess } from "@workspace/supabase-data/actions/user-access/sync-user-access"

async function syncUserRoles(userId: string, roles: readonly AuthRole[]) {
  const access = await syncUserAccess(userId, roles)

  return access.roles.map((role) => ({
    createdAt: new Date().toISOString(),
    role,
    userId,
  }))
}

export { syncUserRoles }
