// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import type { GoogleSyncJobDedupDTO } from "@workspace/supabase-data/modules/google-sync/domain/dto/google-sync-job-dedup.dto.codegen"

export interface GoogleSyncJobDedupListParams {
  limit?: number
  offset?: number
}

export interface GoogleSyncJobDedupListResult {
  rows: GoogleSyncJobDedupDTO[]
}

interface GoogleSyncJobDedupRepository {
  list(params: GoogleSyncJobDedupListParams): Promise<GoogleSyncJobDedupListResult>
  insert(data: Partial<GoogleSyncJobDedupDTO>): Promise<GoogleSyncJobDedupDTO>
  update(id: string, patch: Partial<GoogleSyncJobDedupDTO>): Promise<GoogleSyncJobDedupDTO>
  delete(id: string): Promise<void>
}

export { type GoogleSyncJobDedupRepository }
