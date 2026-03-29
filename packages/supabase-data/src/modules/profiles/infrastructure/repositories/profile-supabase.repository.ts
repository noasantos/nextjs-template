import type { SupabaseClient } from "@supabase/supabase-js"

import { SupabaseRepositoryError } from "@workspace/supabase-data/lib/supabase-repository-error"
import {
  ProfileDTOSchema,
  type ProfileDTO,
} from "@workspace/supabase-data/modules/profiles/domain/dto/profile.dto"
import type { ProfileRepository } from "@workspace/supabase-data/modules/profiles/domain/ports/profile-repository.port"

class ProfileSupabaseRepository implements ProfileRepository {
  constructor(private readonly supabase: SupabaseClient) {}

  async findByUserId(userId: string): Promise<ProfileDTO | null> {
    const { data, error } = await this.supabase
      .from("profiles")
      .select("user_id, email, full_name, avatar_url, created_at, updated_at")
      .eq("user_id", userId)
      .maybeSingle()

    if (error) {
      throw new SupabaseRepositoryError("Failed to load profile.", {
        cause: error,
      })
    }

    if (!data) {
      return null
    }

    return ProfileDTOSchema.parse({
      avatarUrl: data.avatar_url,
      createdAt: data.created_at,
      email: data.email,
      fullName: data.full_name,
      updatedAt: data.updated_at,
      userId: data.user_id,
    })
  }
}

export { ProfileSupabaseRepository }
