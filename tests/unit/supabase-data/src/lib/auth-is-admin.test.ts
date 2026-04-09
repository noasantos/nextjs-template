import { describe, expect, it, vi } from "vitest"

import { getAuthIsAdmin } from "@workspace/supabase-data/lib/auth-is-admin"
import type { TypedSupabaseClient } from "@workspace/supabase-infra/types/supabase"

// @type-escape: TypedSupabaseClient is a deep generic produced by supabase-gen — partial stubs cannot satisfy it structurally; cast is localised here so test bodies stay clean
function makeSupabaseStub(rpcResult: { data: unknown; error: unknown }): TypedSupabaseClient {
  return { rpc: vi.fn().mockResolvedValue(rpcResult) } as unknown as TypedSupabaseClient
}

describe("getAuthIsAdmin", () => {
  it("returns isAdmin true when RPC returns true", async () => {
    const supabase = makeSupabaseStub({ data: true, error: null })

    await expect(getAuthIsAdmin(supabase)).resolves.toEqual({
      ok: true,
      isAdmin: true,
    })
    expect(supabase.rpc).toHaveBeenCalledWith("auth_is_admin")
  })

  it("returns ok false when RPC errors", async () => {
    const err = { message: "boom" }
    const supabase = makeSupabaseStub({ data: null, error: err })

    await expect(getAuthIsAdmin(supabase)).resolves.toEqual({
      ok: false,
      error: err,
    })
  })

  it("returns isAdmin false when RPC returns false (aligned with Postgres auth_is_admin)", async () => {
    const supabase = makeSupabaseStub({ data: false, error: null })

    await expect(getAuthIsAdmin(supabase)).resolves.toEqual({
      ok: true,
      isAdmin: false,
    })
  })
})
