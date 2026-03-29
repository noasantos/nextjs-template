import { afterEach, describe, expect, it, vi } from "vitest"

import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"

afterEach(() => {
  vi.unstubAllEnvs()
})

describe("getSupabasePublicEnv", () => {
  it("returns the required public Supabase environment values", () => {
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "http://127.0.0.1:3000")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "anon-key")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321")

    expect(getSupabasePublicEnv()).toEqual(
      expect.objectContaining({
        authAllowedRedirectOrigins: ["http://127.0.0.1:3000"],
        authAppUrl: "http://127.0.0.1:3000",
        authCookieDomain: undefined,
        supabasePublishableKey: "anon-key",
        supabaseUrl: "http://127.0.0.1:54321",
      })
    )
  })

  it("throws when the auth app URL is missing", () => {
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "anon-key")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321")

    expect(() => getSupabasePublicEnv()).toThrow("NEXT_PUBLIC_AUTH_APP_URL")
  })

  it("throws when the Supabase URL is missing", () => {
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "http://127.0.0.1:3000")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "anon-key")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "")

    expect(() => getSupabasePublicEnv()).toThrow("NEXT_PUBLIC_SUPABASE_URL")
  })

  it("throws when the publishable key is missing", () => {
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "http://127.0.0.1:3000")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321")

    expect(() => getSupabasePublicEnv()).toThrow(
      "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"
    )
  })

  it("normalizes auth app URL when the scheme is omitted (e.g. Vercel env typo)", () => {
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "my-app-auth.vercel.app")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "anon-key")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321")

    expect(getSupabasePublicEnv()).toEqual(
      expect.objectContaining({
        authAllowedRedirectOrigins: ["https://my-app-auth.vercel.app"],
        authAppUrl: "https://my-app-auth.vercel.app",
        supabasePublishableKey: "anon-key",
        supabaseUrl: "http://127.0.0.1:54321",
      })
    )
  })
})
