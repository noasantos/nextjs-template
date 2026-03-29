import "server-only"

import type { SupabaseClient } from "@supabase/supabase-js"

import { ProfileSupabaseRepository } from "@workspace/supabase-data/modules/profiles/infrastructure/repositories/profile-supabase.repository"

async function getProfileByUserId(supabase: SupabaseClient, userId: string) {
  const repository = new ProfileSupabaseRepository(supabase)

  return repository.findByUserId(userId)
}

export { getProfileByUserId }
