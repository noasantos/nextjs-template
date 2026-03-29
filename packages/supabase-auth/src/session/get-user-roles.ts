import "server-only"

import { getAccess } from "@workspace/supabase-auth/session/get-access"
import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"

async function getUserRoles(): Promise<AuthRole[]> {
  return (await getAccess()).roles
}

export { getUserRoles }
