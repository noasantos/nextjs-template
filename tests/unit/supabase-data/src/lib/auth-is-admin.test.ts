import { describe, expect, it, vi } from "vitest"

import type { TypedSupabaseClient } from "@workspace/supabase-infra/types/supabase"

import { getAuthIsAdmin } from "@workspace/supabase-data/lib/auth-is-admin"

describe("getAuthIsAdmin", () => {
  it("returns isAdmin true when RPC returns true", async () => {
    const supabase = {
      rpc: vi.fn().mockResolvedValue({ data: true, error: null }),
    } as unknown as TypedSupabaseClient

    await expect(getAuthIsAdmin(supabase)).resolves.toEqual({
      ok: true,
      isAdmin: true,
    })
    expect(supabase.rpc).toHaveBeenCalledWith("auth_is_admin")
  })

  it("returns ok false when RPC errors", async () => {
    const err = { message: "boom" }
    const supabase = {
      rpc: vi.fn().mockResolvedValue({ data: null, error: err }),
    } as unknown as TypedSupabaseClient

    await expect(getAuthIsAdmin(supabase)).resolves.toEqual({
      ok: false,
      error: err,
    })
  })

  it("returns isAdmin false when RPC returns false (aligned with Postgres auth_is_admin)", async () => {
    const supabase = {
      rpc: vi.fn().mockResolvedValue({ data: false, error: null }),
    } as unknown as TypedSupabaseClient

    await expect(getAuthIsAdmin(supabase)).resolves.toEqual({
      ok: true,
      isAdmin: false,
    })
  })
})
