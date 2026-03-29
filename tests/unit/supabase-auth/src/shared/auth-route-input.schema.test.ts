import { describe, expect, it } from "vitest"

import {
  authCallbackSearchParamsSchema,
  authConfirmSearchParamsSchema,
  authLogoutSearchParamsSchema,
} from "@workspace/supabase-auth/shared/auth-route-input.schema"

describe("auth route input schemas", () => {
  it("accepts valid callback parameters", () => {
    expect(
      authCallbackSearchParamsSchema.parse({
        code: "code-123",
        redirectTo: "http://localhost:3000/account",
      })
    ).toEqual({
      code: "code-123",
      redirectTo: "http://localhost:3000/account",
    })
  })

  it("rejects callback parameters when the code is blank", () => {
    const parsed = authCallbackSearchParamsSchema.safeParse({
      code: " ",
      redirectTo: null,
    })

    expect(parsed.success).toBe(false)
  })

  it("accepts valid auth confirm parameters", () => {
    expect(
      authConfirmSearchParamsSchema.parse({
        redirectTo: "http://localhost:3000/account",
        tokenHash: "hash-123",
        type: "magiclink",
      })
    ).toEqual({
      redirectTo: "http://localhost:3000/account",
      tokenHash: "hash-123",
      type: "magiclink",
    })
  })

  it("rejects unknown auth confirm OTP types", () => {
    const parsed = authConfirmSearchParamsSchema.safeParse({
      redirectTo: null,
      tokenHash: "hash-123",
      type: "sms",
    })

    expect(parsed.success).toBe(false)
  })

  it("accepts logout parameters with or without redirect_to", () => {
    expect(
      authLogoutSearchParamsSchema.parse({
        redirectTo: "http://localhost:3000/account",
      })
    ).toEqual({
      redirectTo: "http://localhost:3000/account",
    })

    expect(
      authLogoutSearchParamsSchema.parse({
        redirectTo: null,
      })
    ).toEqual({
      redirectTo: null,
    })
  })
})
