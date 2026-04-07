// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import { describe, it } from "vitest"

import { GoogleSyncJobDedupSupabaseRepository } from "@workspace/supabase-data/modules/google-sync/infrastructure/repositories/google-sync-job-dedup-supabase.repository.codegen"

describe.skip("google-sync-job-dedup repository (codegen scaffold)", () => {
  it("CRUD round-trip — wire Supabase test client and un-skip", () => {
    void GoogleSyncJobDedupSupabaseRepository
  })
})
