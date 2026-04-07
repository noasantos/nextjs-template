// codegen:backend — do not hand-edit; regenerate with `pnpm codegen:backend --write`.

import { describe, it } from "vitest"

import { GoogleSyncInboundCoalesceSupabaseRepository } from "@workspace/supabase-data/modules/google-sync/infrastructure/repositories/google-sync-inbound-coalesce-supabase.repository.codegen"

describe.skip("google-sync-inbound-coalesce repository (codegen scaffold)", () => {
  it("CRUD round-trip — wire Supabase test client and un-skip", () => {
    void GoogleSyncInboundCoalesceSupabaseRepository
  })
})
