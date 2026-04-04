import { beforeEach, describe, expect, it, vi } from "vitest"

const { getSupabasePublicEnvMock } = vi.hoisted(() => ({
  getSupabasePublicEnvMock: vi.fn(),
}))

vi.mock("@workspace/supabase-infra/env/public", () => ({
  getSupabasePublicEnv: getSupabasePublicEnvMock,
}))

import {
  buildAuthAccessDeniedUrl,
  buildAuthCallbackUrl,
  buildAuthLogoutUrl,
  buildAuthSignInUrl,
  getSafeRedirectTo,
  isSafeRedirectTo,
} from "@workspace/supabase-auth/shared/auth-redirect"

beforeEach(() => {
  getSupabasePublicEnvMock.mockReturnValue({
    authAllowedRedirectOrigins: ["http://localhost:3000", "http://localhost:3001"],
    authAppUrl: "http://localhost:3000",
    supabasePublishableKey: "pk",
    supabaseUrl: "http://localhost:54321",
  })
})

describe("auth redirect helpers", () => {
  it("accepts allowed redirect origins", () => {
    expect(isSafeRedirectTo("http://localhost:3000/account")).toBe(true)
  })

  it("falls back when the redirect origin is not allowed", () => {
    expect(getSafeRedirectTo("https://evil.example/steal")).toBe("http://localhost:3000/sign-in")
  })

  it("builds callback and sign-in URLs with sanitized redirect params", () => {
    expect(buildAuthCallbackUrl("https://evil.example")).toBe(
      "http://localhost:3000/callback?redirect_to=http%3A%2F%2Flocalhost%3A3000%2Flogin"
    )
    expect(buildAuthSignInUrl("http://localhost:3000/account/settings")).toBe(
      "http://localhost:3000/sign-in?redirect_to=http%3A%2F%2Flocalhost%3A3000%2Faccount%2Fsettings"
    )
  })

  it("includes required access context and logout fallback", () => {
    expect(buildAuthAccessDeniedUrl("http://localhost:3000/account", ["admin"])).toBe(
      "http://localhost:3000/access-denied?redirect_to=http%3A%2F%2Flocalhost%3A3000%2Faccount&required=admin"
    )
    expect(buildAuthLogoutUrl("https://evil.example")).toBe(
      "http://localhost:3000/logout?redirect_to=http%3A%2F%2Flocalhost%3A3000%2Flogin"
    )
  })
})
