import type { JwtPayload } from "@supabase/supabase-js"
import { beforeEach, describe, expect, it, vi } from "vitest"

const { getSupabasePublicEnvMock } = vi.hoisted(() => ({
  getSupabasePublicEnvMock: vi.fn(),
}))

vi.mock("@workspace/supabase-infra/env/public", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@workspace/supabase-infra/env/public")>()
  return {
    ...actual,
    getSupabasePublicEnv: getSupabasePublicEnvMock,
  }
})

import {
  getContinueDecision,
  resolveAuthorizedRedirect,
} from "@workspace/supabase-auth/shared/app-destination"

beforeEach(() => {
  getSupabasePublicEnvMock.mockReturnValue({
    authAllowedRedirectOrigins: ["http://localhost:3000"],
    authAppUrl: "http://localhost:3000",
    supabasePublishableKey: "pk",
    supabaseUrl: "http://localhost:54321",
  })

  process.env.NEXT_PUBLIC_AUTH_APP_URL = "http://localhost:3000"
})

describe("getContinueDecision", () => {
  it("redirects to the requested destination when the path is not a gated app segment", () => {
    expect(
      getContinueDecision({
        redirectTo: "http://localhost:3000/account",
        roles: ["admin"],
      })
    ).toEqual({
      href: "http://localhost:3000/account",
      kind: "redirect",
    })
  })

  it("sends the shared /sign-in route to the default workspace for admin", () => {
    expect(
      getContinueDecision({
        redirectTo: "http://localhost:3000/sign-in",
        roles: ["admin"],
      })
    ).toEqual({
      href: "http://localhost:3000/",
      kind: "redirect",
    })
  })

  it("treats app root as public institutional", () => {
    expect(
      getContinueDecision({
        redirectTo: "http://localhost:3000/",
        roles: ["admin"],
      })
    ).toEqual({
      href: "http://localhost:3000/",
      kind: "redirect",
    })
  })

  it("keeps non-landing auth paths on the auth app", () => {
    expect(
      getContinueDecision({
        redirectTo: "http://localhost:3000/mfa",
        roles: ["admin"],
      })
    ).toEqual({
      href: "http://localhost:3000/mfa",
      kind: "redirect",
    })
  })

  it("sends session-without-roles away from /sign-in to institutional (avoids 307 redirect loop)", () => {
    expect(
      getContinueDecision({
        redirectTo: "http://localhost:3000/sign-in",
        roles: [],
      })
    ).toEqual({
      href: "http://localhost:3000/",
      kind: "redirect",
    })
  })
})

describe("resolveAuthorizedRedirect", () => {
  it("sends auth landing to institutional when claims have no roles (avoids /sign-in loop)", () => {
    expect(
      resolveAuthorizedRedirect({
        claims: {
          app_metadata: { roles: [] },
          sub: "user-1",
        } as unknown as JwtPayload,
        redirectTo: "http://localhost:3000/sign-in",
      })
    ).toBe("http://localhost:3000/")
  })

  it("sends auth landing to the default workspace for admin", () => {
    expect(
      resolveAuthorizedRedirect({
        claims: {
          app_metadata: { roles: ["admin"] },
          sub: "user-1",
        } as unknown as JwtPayload,
        redirectTo: "http://localhost:3000/sign-in",
      })
    ).toBe("http://localhost:3000/")
  })

  it("keeps non-landing auth paths unchanged", () => {
    expect(
      resolveAuthorizedRedirect({
        claims: {
          app_metadata: { roles: ["admin"] },
          sub: "user-1",
        } as unknown as JwtPayload,
        redirectTo: "http://localhost:3000/mfa",
      })
    ).toBe("http://localhost:3000/mfa")
  })
})
