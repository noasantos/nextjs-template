// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import { describe, it } from "vitest"

import { GoogleSyncWorkerMetricsSupabaseRepository } from "@workspace/supabase-data/modules/google-sync/infrastructure/repositories/google-sync-worker-metrics-supabase.repository.codegen"

describe.skip("google-sync-worker-metrics repository (codegen scaffold)", () => {
  it("CRUD round-trip — wire Supabase test client and un-skip", () => {
    void GoogleSyncWorkerMetricsSupabaseRepository
  })
})
