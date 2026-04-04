import { describe, expect, it } from "vitest"

import { createAuthFormSchemas } from "@workspace/supabase-auth/shared/auth-form-schemas"

const testMessages = {
  emailRequired: "Enter your email.",
  emailInvalid: "Enter a valid email address.",
  passwordMin: "Password must be at least 8 characters.",
  confirmPasswordRequired: "Confirm your password.",
  passwordsMatch: "Passwords must match.",
  mfaCodeFormat: "Enter the 6-digit code from your authenticator app.",
}

const { signInSchema, passwordResetSchema, mfaCodeSchema } = createAuthFormSchemas(
  (key) => testMessages[key]
)

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
