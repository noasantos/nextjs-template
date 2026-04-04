import { afterEach, describe, expect, it, vi } from "vitest"

const {
  buildAuthContinueUrlMock,
  exchangeCodeForSessionMock,
  getSafeRedirectToMock,
  protectSensitiveAuthRouteMock,
} = vi.hoisted(() => ({
  buildAuthContinueUrlMock: vi.fn(
    (redirectTo) => `http://localhost:3000/continue?redirect_to=${encodeURIComponent(redirectTo)}`
  ),
  exchangeCodeForSessionMock: vi.fn(),
  getSafeRedirectToMock: vi.fn((value) => value ?? "http://localhost:3000/sign-in"),
  protectSensitiveAuthRouteMock: vi.fn(async () => ({ ok: true })),
}))

vi.mock("@workspace/supabase-auth/server/exchange-code-for-session", () => ({
  exchangeCodeForSession: exchangeCodeForSessionMock,
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

import { GET } from "@/app/(auth-handlers)/callback/route"

afterEach(() => {
  buildAuthContinueUrlMock.mockReset()
  exchangeCodeForSessionMock.mockReset()
  getSafeRedirectToMock.mockReset()
  protectSensitiveAuthRouteMock.mockReset()
  protectSensitiveAuthRouteMock.mockResolvedValue({ ok: true })
})

describe("auth callback route", () => {
  it("redirects to an error when the code is missing", async () => {
    const response = await GET(
      new Request(
        "http://localhost:3000/callback?redirect_to=http://localhost:3000/account"
      ) as never
    )

    expect(response.headers.get("location")).toBe(
      "http://localhost:3000/?auth=callback_missing_code"
    )
  })

  it("redirects to continue when the exchange succeeds", async () => {
    exchangeCodeForSessionMock.mockResolvedValue({ error: null })

    const response = await GET(
      new Request(
        "http://localhost:3000/callback?code=abc&redirect_to=http://localhost:3000/account"
      ) as never
    )

    expect(response.headers.get("location")).toBe(
      "http://localhost:3000/continue?redirect_to=http%3A%2F%2Flocalhost%3A3000%2Faccount"
    )
  })

  it("returns 429 when abuse protection blocks the request", async () => {
    protectSensitiveAuthRouteMock.mockResolvedValue({
      key: "auth_callback",
      ok: false,
      reason: "rate_limited",
      retryAfterSeconds: 30,
    })

    const response = await GET(new Request("http://localhost:3000/callback?code=abc") as never)

    expect(response.status).toBe(429)
    expect(response.headers.get("retry-after")).toBe("30")
    expect(exchangeCodeForSessionMock).not.toHaveBeenCalled()
  })
})
