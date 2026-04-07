// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import type { GoogleSyncLogsDTO } from "@workspace/supabase-data/modules/google-sync/domain/dto/google-sync-logs.dto.codegen"

export interface GoogleSyncLogsListParams {
  limit?: number
  offset?: number
}

export interface GoogleSyncLogsListResult {
  rows: GoogleSyncLogsDTO[]
}

interface GoogleSyncLogsRepository {
  findById(id: string): Promise<GoogleSyncLogsDTO | null>
  list(params: GoogleSyncLogsListParams): Promise<GoogleSyncLogsListResult>
  insert(data: Partial<GoogleSyncLogsDTO>): Promise<GoogleSyncLogsDTO>
  update(id: string, patch: Partial<GoogleSyncLogsDTO>): Promise<GoogleSyncLogsDTO>
  delete(id: string): Promise<void>
}

export { type GoogleSyncLogsRepository }
