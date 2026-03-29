import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

const {
  createBrowserAuthClientMock,
  getSupabasePublicEnvMock,
  getAuthenticatorAssuranceLevelMock,
  listFactorsMock,
  enrollMock,
  signInWithOtpMock,
  resetPasswordForEmailMock,
  signOutMock,
  unenrollMock,
  updateUserMock,
  challengeAndVerifyMock,
} = vi.hoisted(() => ({
  challengeAndVerifyMock: vi.fn(),
  createBrowserAuthClientMock: vi.fn(),
  enrollMock: vi.fn(),
  getAuthenticatorAssuranceLevelMock: vi.fn(),
  getSupabasePublicEnvMock: vi.fn(),
  listFactorsMock: vi.fn(),
  resetPasswordForEmailMock: vi.fn(),
  signInWithOtpMock: vi.fn(),
  signOutMock: vi.fn(),
  unenrollMock: vi.fn(),
  updateUserMock: vi.fn(),
}))

vi.mock("@workspace/supabase-auth/browser/create-browser-auth-client", () => ({
  createBrowserAuthClient: createBrowserAuthClientMock,
}))

vi.mock("@workspace/supabase-infra/env/public", () => ({
  getSupabasePublicEnv: getSupabasePublicEnvMock,
}))

import { enrollTotpFactor } from "@workspace/supabase-auth/browser/enroll-totp-factor"
import { getAuthenticatorAssuranceLevel } from "@workspace/supabase-auth/browser/get-authenticator-assurance-level"
import { getMfaFactors } from "@workspace/supabase-auth/browser/get-mfa-factors"
import { sendPasswordResetEmail } from "@workspace/supabase-auth/browser/send-password-reset-email"
import { signInWithMagicLink } from "@workspace/supabase-auth/browser/sign-in-with-magic-link"
import { signOut } from "@workspace/supabase-auth/browser/sign-out"
import { unenrollFactor } from "@workspace/supabase-auth/browser/unenroll-factor"
import { updatePassword } from "@workspace/supabase-auth/browser/update-password"
import { verifyTotpChallenge } from "@workspace/supabase-auth/browser/verify-totp-challenge"

beforeEach(() => {
  getSupabasePublicEnvMock.mockReturnValue({
    authAllowedRedirectOrigins: [
      "http://localhost:3000",
      "http://localhost:3000",
    ],
    authAppUrl: "http://localhost:3000",
    supabasePublishableKey: "anon-key",
    supabaseUrl: "http://localhost:54321",
  })
  createBrowserAuthClientMock.mockReturnValue({
    auth: {
      mfa: {
        challengeAndVerify: challengeAndVerifyMock,
        enroll: enrollMock,
        getAuthenticatorAssuranceLevel: getAuthenticatorAssuranceLevelMock,
        listFactors: listFactorsMock,
        unenroll: unenrollMock,
      },
      resetPasswordForEmail: resetPasswordForEmailMock,
      signInWithOtp: signInWithOtpMock,
      signOut: signOutMock,
      updateUser: updateUserMock,
    },
  })
})

afterEach(() => {
  challengeAndVerifyMock.mockReset()
  createBrowserAuthClientMock.mockReset()
  enrollMock.mockReset()
  getAuthenticatorAssuranceLevelMock.mockReset()
  getSupabasePublicEnvMock.mockReset()
  listFactorsMock.mockReset()
  resetPasswordForEmailMock.mockReset()
  signInWithOtpMock.mockReset()
  signOutMock.mockReset()
  unenrollMock.mockReset()
  updateUserMock.mockReset()
})

describe("browser MFA and session actions", () => {
  it("wraps MFA helpers and sign-out", async () => {
    enrollMock.mockResolvedValue({ data: { id: "factor-1" }, error: null })
    getAuthenticatorAssuranceLevelMock.mockResolvedValue({
      data: { currentLevel: "aal1", nextLevel: "aal2" },
      error: null,
    })
    listFactorsMock.mockResolvedValue({ data: { all: [] }, error: null })
    signOutMock.mockResolvedValue({ error: null })
    unenrollMock.mockResolvedValue({ data: { id: "factor-1" }, error: null })
    challengeAndVerifyMock.mockResolvedValue({
      data: { access_token: "token" },
      error: null,
    })

    await expect(enrollTotpFactor({ friendlyName: "Phone" })).resolves.toEqual({
      data: { id: "factor-1" },
      error: null,
    })
    await expect(getAuthenticatorAssuranceLevel()).resolves.toEqual({
      data: { currentLevel: "aal1", nextLevel: "aal2" },
      error: null,
    })
    await expect(getMfaFactors()).resolves.toEqual({
      data: { all: [] },
      error: null,
    })
    await expect(signOut()).resolves.toEqual({ error: null })
    await expect(unenrollFactor({ factorId: "factor-1" })).resolves.toEqual({
      data: { id: "factor-1" },
      error: null,
    })
    await expect(
      verifyTotpChallenge({ code: "123456", factorId: "factor-1" })
    ).resolves.toEqual({
      data: { access_token: "token" },
      error: null,
    })
  })

  it("wraps password reset, magic link, and password update with sanitized redirects", async () => {
    resetPasswordForEmailMock.mockResolvedValue({ data: {}, error: null })
    signInWithOtpMock.mockResolvedValue({ data: {}, error: null })
    updateUserMock.mockResolvedValue({
      data: { user: { id: "user-1" } },
      error: null,
    })

    await expect(
      sendPasswordResetEmail({
        email: "user@example.test",
        redirectTo: "http://localhost:3000/account",
      })
    ).resolves.toEqual({ error: null })
    await expect(
      signInWithMagicLink({
        email: "user@example.test",
        redirectTo: "http://localhost:3000/account",
      })
    ).resolves.toEqual({ data: {}, error: null })
    await expect(
      updatePassword({
        password: "Password123!",
      })
    ).resolves.toEqual({
      data: { user: { id: "user-1" } },
      error: null,
    })
  })
})
