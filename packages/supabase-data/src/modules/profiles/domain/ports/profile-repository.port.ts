import type { ProfileDTO } from "@workspace/supabase-data/modules/profiles/domain/dto/profile.dto"

interface ProfileRepository {
  findByUserId(userId: string): Promise<ProfileDTO | null>
}

export { type ProfileRepository }
