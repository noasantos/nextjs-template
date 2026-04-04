import type { SupabaseClient } from "@supabase/supabase-js"

import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"
import { SupabaseRepositoryError } from "@workspace/supabase-data/lib/supabase-repository-error"
import {
  UserRoleDTOSchema,
  type UserRoleDTO,
} from "@workspace/supabase-data/modules/user-roles/domain/dto/user-role.dto"
import type { UserRoleRepository } from "@workspace/supabase-data/modules/user-roles/domain/ports/user-role-repository.port"

class UserRoleSupabaseRepository implements UserRoleRepository {
  constructor(private readonly supabase: SupabaseClient) {}

  async findByUserId(userId: string): Promise<UserRoleDTO[]> {
    const { data, error } = await this.supabase
      .from("user_roles")
      .select("user_id, role, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: true })

    if (error) {
      throw new SupabaseRepositoryError("Failed to load user roles.", {
        cause: error,
      })
    }

    if (!data) {
      throw new SupabaseRepositoryError("User roles query returned no rows.")
    }

    return data.map((row: Record<string, unknown>) =>
      UserRoleDTOSchema.parse({
        createdAt: row.created_at,
        role: row.role,
        userId: row.user_id,
      })
    )
  }

  async replaceUserRoles(userId: string, roles: readonly AuthRole[]): Promise<UserRoleDTO[]> {
    const { error: deleteError } = await this.supabase
      .from("user_roles")
      .delete()
      .eq("user_id", userId)

    if (deleteError) {
      throw new SupabaseRepositoryError("Failed to replace user roles.", {
        cause: deleteError,
      })
    }

    if (roles.length === 0) {
      return []
    }

    const { data, error } = await this.supabase
      .from("user_roles")
      .insert(roles.map((role) => ({ role, user_id: userId })))
      .select("user_id, role, created_at")

    if (error) {
      throw new SupabaseRepositoryError("Failed to persist user roles.", {
        cause: error,
      })
    }

    if (!data) {
      throw new SupabaseRepositoryError("User roles insert returned no rows.")
    }

    return data.map((row: Record<string, unknown>) =>
      UserRoleDTOSchema.parse({
        createdAt: row.created_at,
        role: row.role,
        userId: row.user_id,
      })
    )
  }
}

export { UserRoleSupabaseRepository }
