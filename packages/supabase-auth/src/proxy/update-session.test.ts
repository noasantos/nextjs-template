import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

const { createServerClientMock, getSupabasePublicEnvMock } = vi.hoisted(() => ({
  createServerClientMock: vi.fn(),
  getSupabasePublicEnvMock: vi.fn(),
}))

vi.mock("@supabase/ssr", () => ({
  createServerClient: createServerClientMock,
}))

vi.mock("@workspace/supabase-infra/env/public", () => ({
  getSupabasePublicEnv: getSupabasePublicEnvMock,
}))

import { NextResponse } from "next/server"

import { updateSession } from "@workspace/supabase-auth/proxy/update-session"
import {
  LOG_CORRELATION_ID_HEADER,
  LOG_TRACE_ID_HEADER,
} from "@workspace/supabase-auth/shared/request-headers"

beforeEach(() => {
  getSupabasePublicEnvMock.mockReturnValue({
    authAllowedRedirectOrigins: ["http://localhost:3000", "http://localhost:3000"],
    authAppUrl: "http://localhost:3000",
    authCookieDomain: undefined,
    supabasePublishableKey: "anon-key",
    supabaseUrl: "http://localhost:54321",
  })
})

afterEach(() => {
  createServerClientMock.mockReset()
  getSupabasePublicEnvMock.mockReset()
})

describe("updateSession", () => {
  it("adds the request URL header, seeds correlation, and syncs cookies into the response", async () => {
    createServerClientMock.mockImplementation((_url, _key, options) => ({
      auth: {
        getClaims: vi.fn(async () => {
          options.cookies.setAll([
            {
              name: "sb-local-auth-token",
              options: {
                path: "/",
              },
              value: "refreshed-token",
            },
          ])
        }),
      },
    }))

    const requestCookies = new Map<string, string>()
    const request = {
      cookies: {
        getAll: vi.fn(() =>
          [...requestCookies.entries()].map(([name, value]) => ({
            name,
            value,
          }))
        ),
        set: vi.fn((name: string, value: string) => {
          requestCookies.set(name, value)
        }),
      },
      headers: new Headers(),
      nextUrl: new URL("http://localhost:3000/account"),
    }

    const response = await updateSession(request as never)

    expect(createServerClientMock).toHaveBeenCalled()
    expect(response.headers.get("x-middleware-override-headers")).toContain("x-app-request-url")
    expect(response.headers.get("x-middleware-override-headers")).toContain("cookie")
    expect(response.headers.get("x-middleware-request-cookie")).toContain(
      "sb-local-auth-token=refreshed-token"
    )
    expect(response.headers.get(LOG_CORRELATION_ID_HEADER)).toBeTruthy()
    expect(response.headers.get(LOG_TRACE_ID_HEADER)).toBeTruthy()
  })

  it("keeps correlation headers even when claims lookup fails", async () => {
    createServerClientMock.mockReturnValue({
      auth: {
        getClaims: vi.fn(async () => {
          throw new Error("refresh failed")
        }),
      },
    })

    const request = {
      cookies: {
        getAll: vi.fn(() => []),
        set: vi.fn(),
      },
      headers: new Headers(),
      nextUrl: new URL("http://localhost:3000/account"),
    }

    const response = await updateSession(request as never)

    expect(response.headers.get(LOG_CORRELATION_ID_HEADER)).toBeTruthy()
    expect(response.headers.get(LOG_TRACE_ID_HEADER)).toBeTruthy()
  })

  it("preserves upstream middleware headers when upstreamResponse is provided", async () => {
    createServerClientMock.mockReturnValue({
      auth: {
        getClaims: vi.fn(async () => {}),
      },
    })

    const request = {
      cookies: {
        getAll: vi.fn(() => []),
        set: vi.fn(),
      },
      headers: new Headers(),
      nextUrl: new URL("http://localhost:3000/"),
    }

    const upstream = NextResponse.next()
    upstream.headers.set("Link", '</pt>; rel="alternate"; hreflang="pt"')
    upstream.headers.set("X-Next-Intl-Locale", "en")

    const response = await updateSession(request as never, undefined, upstream)

    expect(response.headers.get("Link")).toContain("hreflang")
    expect(response.headers.get("X-Next-Intl-Locale")).toBe("en")
  })
})
