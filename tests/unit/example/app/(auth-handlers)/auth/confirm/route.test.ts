import { afterEach, describe, expect, it, vi } from "vitest"

const {
  buildAuthContinueUrlMock,
  getSafeRedirectToMock,
  protectSensitiveAuthRouteMock,
  verifyOtpMock,
} =
  vi.hoisted(() => ({
    buildAuthContinueUrlMock: vi.fn(
      (redirectTo: string) =>
        `http://localhost:3000/continue?redirect_to=${encodeURIComponent(redirectTo)}`
    ),
    getSafeRedirectToMock: vi.fn(
      (value: string | null) => value ?? "http://localhost:3000/sign-in"
    ),
    protectSensitiveAuthRouteMock: vi.fn(async () => ({ ok: true })),
    verifyOtpMock: vi.fn(),
  }))

vi.mock("@workspace/supabase-auth/server/verify-otp", () => ({
  verifyOtp: verifyOtpMock,
}))

vi.mock("@workspace/supabase-auth/server/sensitive-route-protection", () => ({
  protectSensitiveAuthRoute: protectSensitiveAuthRouteMock,
}))

vi.mock("@workspace/supabase-auth/shared/app-destination", () => ({
  buildAuthContinueUrl: buildAuthContinueUrlMock,
}))

vi.mock("@workspace/supabase-auth/shared/auth-redirect", () => ({
  getSafeRedirectTo: getSafeRedirectToMock,
}))

import { GET } from "@/app/(auth-handlers)/auth/confirm/route"

afterEach(() => {
  buildAuthContinueUrlMock.mockReset()
  getSafeRedirectToMock.mockReset()
  protectSensitiveAuthRouteMock.mockReset()
  protectSensitiveAuthRouteMock.mockResolvedValue({ ok: true })
  verifyOtpMock.mockReset()
})

const baseConfirmUrl = "http://localhost:3000/auth/confirm"

function confirmRequest(search: string) {
  return new Request(`${baseConfirmUrl}${search}`) as never
}

describe("auth confirm route (email OTP)", () => {
  describe("deny: missing token, missing type, or invalid OTP type", () => {
    it.each([
      {
        name: "missing token_hash",
        search: "?type=magiclink",
      },
      {
        name: "missing type",
        search: "?token_hash=abc",
      },
      {
        name: "empty token_hash",
        search: "?token_hash=&type=magiclink",
      },
      {
        name: "invalid type (not an EmailOtpType)",
        search: "?token_hash=abc&type=sms",
      },
      {
        name: "invalid type (unknown string)",
        search: "?token_hash=abc&type=not_a_real_type",
      },
    ])(
      "redirects with confirm_missing_token when $name",
      async ({ search }) => {
        const response = await GET(confirmRequest(search))

        expect(response.headers.get("location")).toBe(
          "http://localhost:3000/?auth=confirm_missing_token"
        )
        expect(verifyOtpMock).not.toHaveBeenCalled()
      }
    )
  })

  describe("deny: verifyOtp returns an error", () => {
    it("redirects with confirm_error", async () => {
      verifyOtpMock.mockResolvedValue({
        error: { message: "invalid or expired token" },
      })

      const response = await GET(
        confirmRequest("?token_hash=hash&type=magiclink")
      )

      expect(response.headers.get("location")).toBe(
        "http://localhost:3000/?auth=confirm_error"
      )
      expect(verifyOtpMock).toHaveBeenCalledTimes(1)
      expect(verifyOtpMock).toHaveBeenCalledWith({
        tokenHash: "hash",
        type: "magiclink",
      })
      expect(buildAuthContinueUrlMock).not.toHaveBeenCalled()
    })
  })

  describe("success: verifyOtp succeeds", () => {
    it.each([
      { type: "signup" as const },
      { type: "invite" as const },
      { type: "magiclink" as const },
      { type: "recovery" as const },
      { type: "email_change" as const },
      { type: "email" as const },
    ])("accepts type $type and redirects to continue URL", async ({ type }) => {
      verifyOtpMock.mockResolvedValue({ error: null })
      getSafeRedirectToMock.mockReturnValue("http://localhost:3000/account")

      const response = await GET(
        confirmRequest(
          `?token_hash=th&type=${type}&redirect_to=http://localhost:3000/account`
        )
      )

      expect(response.headers.get("location")).toBe(
        "http://localhost:3000/continue?redirect_to=http%3A%2F%2Flocalhost%3A3000%2Faccount"
      )
      expect(verifyOtpMock).toHaveBeenCalledWith({
        tokenHash: "th",
        type,
      })
      expect(getSafeRedirectToMock).toHaveBeenCalledWith(
        "http://localhost:3000/account"
      )
      expect(buildAuthContinueUrlMock).toHaveBeenCalledWith(
        "http://localhost:3000/account"
      )
    })
  })

  it("returns 429 when abuse protection blocks the request", async () => {
    protectSensitiveAuthRouteMock.mockResolvedValue({
      key: "auth_confirm",
      ok: false,
      reason: "rate_limited",
      retryAfterSeconds: 45,
    })

    const response = await GET(
      confirmRequest("?token_hash=hash&type=magiclink")
    )

    expect(response.status).toBe(429)
    expect(response.headers.get("retry-after")).toBe("45")
    expect(verifyOtpMock).not.toHaveBeenCalled()
  })
})
