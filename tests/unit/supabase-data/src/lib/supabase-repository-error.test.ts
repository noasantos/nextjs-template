import { describe, expect, it } from "vitest"

import { SupabaseRepositoryError } from "@workspace/supabase-data/lib/supabase-repository-error"

describe("SupabaseRepositoryError", () => {
  it("preserves the message, name, and cause", () => {
    const cause = new Error("boom")
    const error = new SupabaseRepositoryError("failed", { cause })

    expect(error.message).toBe("failed")
    expect(error.name).toBe("SupabaseRepositoryError")
    expect(error.cause).toBe(cause)
  })
})
