import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { createMemorySensitiveRouteProtector } from "@workspace/supabase-auth/server/sensitive-route-protection"

describe("sensitive route protection", () => {
  it("allows requests within the memory window budget", async () => {
    const protector = createMemorySensitiveRouteProtector()
    const headers = new Headers({
      "x-forwarded-for": "127.0.0.1",
    })

    const decision = await protector({
      headers,
      key: "auth_callback",
    })

    expect(decision).toEqual({ ok: true })
  })

  it("blocks when the per-route limit is exceeded", async () => {
    const protector = createMemorySensitiveRouteProtector()
    const headers = new Headers({
      "x-forwarded-for": "127.0.0.1",
    })

    for (let attempt = 0; attempt < 12; attempt += 1) {
      const decision = await protector({
        headers,
        key: "auth_confirm",
      })

      expect(decision.ok).toBe(true)
    }

    const blocked = await protector({
      headers,
      key: "auth_confirm",
    })

    expect(blocked).toMatchObject({
      key: "auth_confirm",
      ok: false,
      reason: "rate_limited",
    })
    expect(blocked.ok ? 0 : blocked.retryAfterSeconds).toBeGreaterThan(0)
  })

  it("prefers cf-connecting-ip over x-forwarded-for for the rate-limit bucket", async () => {
    const protector = createMemorySensitiveRouteProtector()
    const sharedForwarded = "192.168.1.99"

    for (let i = 0; i < 12; i += 1) {
      await protector({
        headers: new Headers({ "x-forwarded-for": sharedForwarded }),
        key: "auth_callback",
      })
    }

    const blockedForwardedOnly = await protector({
      headers: new Headers({ "x-forwarded-for": sharedForwarded }),
      key: "auth_callback",
    })
    expect(blockedForwardedOnly.ok).toBe(false)

    const allowedWithCf = await protector({
      headers: new Headers({
        "cf-connecting-ip": "10.0.0.1",
        "x-forwarded-for": sharedForwarded,
      }),
      key: "auth_callback",
    })
    expect(allowedWithCf).toEqual({ ok: true })
  })
})

describe("protectSensitiveAuthRoute env resolution", () => {
  beforeEach(() => {
    vi.unstubAllEnvs()
    vi.resetModules()
  })

  afterEach(() => {
    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it("uses fail-closed response in production when AUTH_RATE_LIMIT_MODE is unset", async () => {
    vi.stubEnv("NODE_ENV", "production")
    const { protectSensitiveAuthRoute } =
      await import("@workspace/supabase-auth/server/sensitive-route-protection")

    const decision = await protectSensitiveAuthRoute({
      headers: new Headers(),
      key: "auth_confirm",
    })

    expect(decision).toEqual({
      key: "auth_confirm",
      ok: false,
      reason: "abuse_protection_required",
      retryAfterSeconds: 120,
    })
  })

  it("allows pass-through in production when AUTH_RATE_LIMIT_MODE is off", async () => {
    vi.stubEnv("NODE_ENV", "production")
    vi.stubEnv("AUTH_RATE_LIMIT_MODE", "off")
    const { protectSensitiveAuthRoute } =
      await import("@workspace/supabase-auth/server/sensitive-route-protection")

    await expect(
      protectSensitiveAuthRoute({
        headers: new Headers(),
        key: "auth_callback",
      })
    ).resolves.toEqual({ ok: true })
  })

  it("uses memory limiting in test when mode is unset", async () => {
    vi.stubEnv("NODE_ENV", "test")
    const { protectSensitiveAuthRoute } =
      await import("@workspace/supabase-auth/server/sensitive-route-protection")

    const headers = new Headers({ "x-forwarded-for": "203.0.113.50" })
    for (let i = 0; i < 12; i += 1) {
      await expect(protectSensitiveAuthRoute({ headers, key: "auth_callback" })).resolves.toEqual({
        ok: true,
      })
    }

    const blocked = await protectSensitiveAuthRoute({
      headers,
      key: "auth_callback",
    })

    expect(blocked).toMatchObject({
      ok: false,
      reason: "rate_limited",
    })
  })
})
