import { describe, expect, it } from "vitest"

import {
  mfaCodeSchema,
  passwordResetSchema,
  signInSchema,
} from "@/app/[locale]/(auth)/_lib/auth-form-schemas"

describe("auth form schemas", () => {
  it("normalizes sign-in emails", () => {
    expect(
      signInSchema.parse({
        email: "USER@example.test",
        password: "Password123!",
      })
    ).toEqual({
      email: "user@example.test",
      password: "Password123!",
    })
  })

  it("requires matching passwords on reset", () => {
    const parsed = passwordResetSchema.safeParse({
      confirmPassword: "Password999!",
      password: "Password123!",
    })

    expect(parsed.success).toBe(false)
  })

  it("requires a 6-digit MFA code", () => {
    const parsed = mfaCodeSchema.safeParse({
      code: "12345",
    })

    expect(parsed.success).toBe(false)
  })
})
