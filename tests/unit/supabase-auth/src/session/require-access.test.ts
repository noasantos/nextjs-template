/**
 * `requireAccess` composes **roles + permissions** (JWT + optional RPC merge via getAccess).
 *
 * Use `ACCESS_CONTROL_TEMPLATE` literals so expectations match the seeded baseline; swap
 * slugs when your product defines different gates.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { requireAccess } from "@workspace/supabase-auth/session/require-access"
import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"

const { exampleJwtPermission: P, privilegedRole: R } = ACCESS_CONTROL_TEMPLATE

const {
  buildAuthAccessDeniedUrlMock,
  buildAuthSignInUrlMock,
  createServerAuthClientMock,
  getClaimsMock,
  getRequestUrlMock,
  redirectMock,
} = vi.hoisted(() => ({
  buildAuthAccessDeniedUrlMock: vi.fn(
    (redirectTo, required) => `access-denied:${redirectTo}:${required?.join(",")}`
  ),
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
  buildAuthAccessDeniedUrl: buildAuthAccessDeniedUrlMock,
  buildAuthSignInUrl: buildAuthSignInUrlMock,
}))

afterEach(() => {
  buildAuthAccessDeniedUrlMock.mockClear()
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

describe("requireAccess (policy gate template)", () => {
  it("passes when anyOfRoles and anyOfPermissions are satisfied on claims", async () => {
    getClaimsMock.mockResolvedValue({
      app_metadata: {
        permissions: [P],
        roles: [R],
      },
      sub: "user-1",
    })

    await expect(
      requireAccess({
        anyOfPermissions: [P],
        anyOfRoles: [R],
      })
    ).resolves.toMatchObject({
      sub: "user-1",
    })
  })

  it("redirects to sign-in when there is no session", async () => {
    getClaimsMock.mockResolvedValue(null)
    getRequestUrlMock.mockResolvedValue("http://localhost:3000/account")

    await expect(
      requireAccess({
        anyOfPermissions: [P],
      })
    ).rejects.toThrow("REDIRECT:sign-in:http://localhost:3000/account")
  })

  it("redirects to access-denied when RPC-backed access is empty", async () => {
    getClaimsMock.mockResolvedValue({
      app_metadata: {},
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

    await expect(
      requireAccess({
        anyOfPermissions: [P],
        anyOfRoles: [R],
      })
    ).rejects.toThrow(/^REDIRECT:access-denied:/)
  })
})
