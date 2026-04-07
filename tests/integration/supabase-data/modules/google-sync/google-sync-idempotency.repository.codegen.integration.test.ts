// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import { describe, it } from "vitest"

import { GoogleSyncIdempotencySupabaseRepository } from "@workspace/supabase-data/modules/google-sync/infrastructure/repositories/google-sync-idempotency-supabase.repository.codegen"

describe.skip("google-sync-idempotency repository (codegen scaffold)", () => {
  it("CRUD round-trip — wire Supabase test client and un-skip", () => {
    void GoogleSyncIdempotencySupabaseRepository
  })
})
