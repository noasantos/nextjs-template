import "server-only"
import type { SupabaseClient } from "@supabase/supabase-js"

import { UserRoleSupabaseRepository } from "@workspace/supabase-data/modules/user-roles/infrastructure/repositories/user-role-supabase.repository"

async function getUserRolesByUserId(supabase: SupabaseClient, userId: string) {
  const repository = new UserRoleSupabaseRepository(supabase)

  return repository.findByUserId(userId)
}

export { getUserRolesByUserId }
