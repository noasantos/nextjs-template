// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import type { GoogleSyncIdempotencyDTO } from "@workspace/supabase-data/modules/google-sync/domain/dto/google-sync-idempotency.dto.codegen"

export interface GoogleSyncIdempotencyListParams {
  limit?: number
  offset?: number
}

export interface GoogleSyncIdempotencyListResult {
  rows: GoogleSyncIdempotencyDTO[]
}

interface GoogleSyncIdempotencyRepository {
  list(params: GoogleSyncIdempotencyListParams): Promise<GoogleSyncIdempotencyListResult>
  insert(data: Partial<GoogleSyncIdempotencyDTO>): Promise<GoogleSyncIdempotencyDTO>
  update(id: string, patch: Partial<GoogleSyncIdempotencyDTO>): Promise<GoogleSyncIdempotencyDTO>
  delete(id: string): Promise<void>
}

export { type GoogleSyncIdempotencyRepository }
