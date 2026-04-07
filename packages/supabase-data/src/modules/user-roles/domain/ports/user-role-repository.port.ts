/**
 * Template `user-roles` module — hand-maintained (`codegen: false` in domain map).
 * Not removed by `pnpm codegen:clean` (only `*.codegen.*`). See
 * docs/guides/backend-codegen.md.
 */

import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"
import type { UserRoleDTO } from "@workspace/supabase-data/modules/user-roles/domain/dto/user-role.dto"

interface UserRoleRepository {
  findByUserId(userId: string): Promise<UserRoleDTO[]>
  replaceUserRoles(userId: string, roles: readonly AuthRole[]): Promise<UserRoleDTO[]>
}

export { type UserRoleRepository }
