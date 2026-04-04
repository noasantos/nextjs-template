import { describe, expect, it } from "vitest"

import { categorizeError, serializeUnknownError } from "@workspace/logging/errors"

describe("error serialization", () => {
  it("classifies postgres conflicts as database failures", () => {
    expect(categorizeError({ code: "23503", message: "fk failed" })).toBe("database")
  })

  it("classifies auth api failures", () => {
    expect(
      serializeUnknownError({
        message: "auth otp rejected",
        name: "AuthApiError",
        status: 401,
      })
    ).toEqual({
      category: "supabase_auth",
      code: "AuthApiError",
      message: "auth otp rejected",
    })
  })
})
