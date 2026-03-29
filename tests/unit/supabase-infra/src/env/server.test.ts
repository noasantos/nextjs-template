import { afterEach, describe, expect, it, vi } from "vitest"

import { getSupabaseServerEnv } from "@workspace/supabase-infra/env/server"

afterEach(() => {
  vi.unstubAllEnvs()
})

describe("getSupabaseServerEnv", () => {
  it("returns the merged public and server-only environment values", () => {
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "http://127.0.0.1:3000")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "anon-key")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321")
    vi.stubEnv("SUPABASE_SERVICE_ROLE_KEY", "service-role-key")

    expect(getSupabaseServerEnv()).toEqual(
      expect.objectContaining({
        authAllowedRedirectOrigins: ["http://127.0.0.1:3000"],
        authAppUrl: "http://127.0.0.1:3000",
        authCookieDomain: undefined,
        serviceRoleKey: "service-role-key",
        supabasePublishableKey: "anon-key",
        supabaseUrl: "http://127.0.0.1:54321",
      })
    )
  })

  it("throws when the service role key is missing in production", () => {
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "http://127.0.0.1:3000")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "anon-key")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321")
    vi.stubEnv("SUPABASE_SERVICE_ROLE_KEY", "")
    vi.stubEnv("VERCEL", "1")

    expect(() => getSupabaseServerEnv()).toThrow("SUPABASE_SERVICE_ROLE_KEY")
  })
})
