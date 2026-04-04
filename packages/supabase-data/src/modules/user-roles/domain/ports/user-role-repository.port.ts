import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"
import type { UserRoleDTO } from "@workspace/supabase-data/modules/user-roles/domain/dto/user-role.dto"

interface UserRoleRepository {
  findByUserId(userId: string): Promise<UserRoleDTO[]>
  replaceUserRoles(userId: string, roles: readonly AuthRole[]): Promise<UserRoleDTO[]>
}

export { type UserRoleRepository }
