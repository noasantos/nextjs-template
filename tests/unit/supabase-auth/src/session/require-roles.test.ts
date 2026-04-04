/**
 * `requireRoles` checks **AuthRole** slugs (JWT + merged DB payload). Use the same
 * template privileged slug as RLS / seed docs (`ACCESS_CONTROL_TEMPLATE`).
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { requireRoles } from "@workspace/supabase-auth/session/require-roles"
import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"

const { privilegedRole: R } = ACCESS_CONTROL_TEMPLATE

const {
  buildAuthContinueUrlMock,
  buildAuthSignInUrlMock,
  createServerAuthClientMock,
  getClaimsMock,
  getRequestUrlMock,
  redirectMock,
} = vi.hoisted(() => ({
  buildAuthContinueUrlMock: vi.fn((redirectTo) => `continue:${redirectTo}`),
  buildAuthSignInUrlMock: vi.fn((redirectTo) => `sign-in:${redirectTo}`),
  createServerAuthClientMock: vi.fn(),
  getClaimsMock: vi.fn(),
  getRequestUrlMock: vi.fn(),
  redirectMock: vi.fn((value: string) => {
    throw new Error(`REDIRECT:${value}`)
  }),
}))

vi.mock("@workspace/supabase-auth/session/get-claims", () => ({
  getClaims: getClaimsMock,
}))

vi.mock("@workspace/supabase-auth/server/create-server-auth-client", () => ({
  createServerAuthClient: createServerAuthClientMock,
}))

vi.mock("@workspace/supabase-auth/server/get-request-url", () => ({
  getRequestUrl: getRequestUrlMock,
}))

vi.mock("next/navigation", () => ({
  redirect: redirectMock,
}))

vi.mock("@workspace/supabase-auth/shared/auth-redirect", () => ({
  buildAuthSignInUrl: buildAuthSignInUrlMock,
}))

vi.mock("@workspace/supabase-auth/shared/app-destination", () => ({
  buildAuthContinueUrl: buildAuthContinueUrlMock,
}))

afterEach(() => {
  buildAuthContinueUrlMock.mockClear()
  buildAuthSignInUrlMock.mockClear()
  createServerAuthClientMock.mockReset()
  getClaimsMock.mockReset()
  getRequestUrlMock.mockReset()
})

beforeEach(() => {
  createServerAuthClientMock.mockResolvedValue({
    rpc: vi.fn().mockResolvedValue({ data: null, error: null }),
  })
})

describe("requireRoles (role gate template)", () => {
  it("returns claims when JWT or RPC supplies an accepted role", async () => {
    getClaimsMock.mockResolvedValue({
      app_metadata: { roles: [R] },
      sub: "user-1",
    })
    createServerAuthClientMock.mockResolvedValue({
      rpc: vi.fn().mockResolvedValue({
        data: [
          {
            access_version: 1,
            permissions: [],
            roles: [R],
            subscription: {},
            user_id: "user-1",
          },
        ],
        error: null,
      }),
    })

    await expect(requireRoles({ anyOf: [R] })).resolves.toMatchObject({
      sub: "user-1",
    })
  })

  it("redirects to sign-in when there is no session", async () => {
    getClaimsMock.mockResolvedValue(null)
    getRequestUrlMock.mockResolvedValue("http://localhost:3000/account")

    await expect(requireRoles({ anyOf: [R] })).rejects.toThrow(
      "REDIRECT:sign-in:http://localhost:3000/account"
    )
  })

  it("redirects to continue when no required role is present", async () => {
    getClaimsMock.mockResolvedValue({
      app_metadata: { roles: [] },
      sub: "user-1",
    })
    createServerAuthClientMock.mockResolvedValue({
      rpc: vi.fn().mockResolvedValue({
        data: [
          {
            access_version: 1,
            permissions: [],
            roles: [],
            subscription: {},
            user_id: "user-1",
          },
        ],
        error: null,
      }),
    })

    await expect(requireRoles({ anyOf: [R] })).rejects.toThrow(/^REDIRECT:continue:/)
  })
})
