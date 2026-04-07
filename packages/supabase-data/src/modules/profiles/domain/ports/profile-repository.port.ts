/**
 * Template `profiles` module — hand-maintained (`codegen: false` in domain map).
 * Not removed by `pnpm codegen:clean` (only `*.codegen.*` filenames). See
 * docs/guides/backend-codegen.md.
 */

import type { ProfileDTO } from "@workspace/supabase-data/modules/profiles/domain/dto/profile.dto"

interface ProfileRepository {
  findByUserId(userId: string): Promise<ProfileDTO | null>
}

export { type ProfileRepository }
