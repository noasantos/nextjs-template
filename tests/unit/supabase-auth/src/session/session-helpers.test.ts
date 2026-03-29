/**
 * Unit coverage for `getAccess` / `getUserRoles` with **mocked** RPC + claims.
 *
 * Role and permission strings come from `ACCESS_CONTROL_TEMPLATE` so they stay aligned
 * with integration tests and seed data.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"

const {
  createServerAuthClientMock,
  getClaimsMock,
  getRequestUrlMock,
  redirectMock,
} = vi.hoisted(() => ({
  createServerAuthClientMock: vi.fn(),
  getClaimsMock: vi.fn(),
  getRequestUrlMock: vi.fn(),
  redirectMock: vi.fn((value: string) => {
    throw new Error(`REDIRECT:${value}`)
  }),
}))

vi.mock("@workspace/supabase-auth/server/create-server-auth-client", () => ({
  createServerAuthClient: createServerAuthClientMock,
}))

vi.mock("@workspace/supabase-auth/session/get-claims", () => ({
  getClaims: getClaimsMock,
}))

vi.mock("@workspace/supabase-auth/server/get-request-url", () => ({
  getRequestUrl: getRequestUrlMock,
}))

vi.mock("next/navigation", () => ({
  redirect: redirectMock,
}))

vi.mock("@workspace/supabase-auth/shared/auth-redirect", () => ({
  buildAuthSignInUrl: vi.fn((redirectTo) => `sign-in:${redirectTo}`),
}))

import { getAccess } from "@workspace/supabase-auth/session/get-access"
import { getSession } from "@workspace/supabase-auth/session/get-session"
import { getUserRoles } from "@workspace/supabase-auth/session/get-user-roles"
import { getUser } from "@workspace/supabase-auth/session/get-user"
import { requireUser } from "@workspace/supabase-auth/session/require-user"

const { exampleJwtPermission: P, privilegedRole: R } = ACCESS_CONTROL_TEMPLATE

afterEach(() => {
  createServerAuthClientMock.mockReset()
  getClaimsMock.mockReset()
  getRequestUrlMock.mockReset()
})

beforeEach(() => {
  createServerAuthClientMock.mockResolvedValue({
    rpc: vi.fn().mockResolvedValue({ data: null, error: null }),
  })
})

describe("session helpers (access: mocked claims + RPC)", () => {
  it("maps JWT app_metadata roles and permissions into getAccess / getUserRoles", async () => {
    getClaimsMock.mockResolvedValue({
      app_metadata: {
        permissions: [P, P],
        roles: [R, R],
      },
      sub: "user-1",
    })

    await expect(getAccess()).resolves.toEqual({
      accessVersion: null,
      permissions: [P],
      roles: [R],
      subscription: {},
    })
    await expect(getUserRoles()).resolves.toEqual([R])
  })

  it("falls back to get_my_access_payload when JWT has no role list", async () => {
    getClaimsMock.mockResolvedValue({
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

    await expect(getAccess()).resolves.toEqual({
      accessVersion: 1,
      permissions: [],
      roles: [R],
      subscription: {},
    })
    await expect(getUserRoles()).resolves.toEqual([R])
  })

  it("when JWT already has roles, prefers DB subscription snapshot from RPC", async () => {
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
            subscription: { plan: "pro" },
            user_id: "user-1",
          },
        ],
        error: null,
      }),
    })

    await expect(getAccess()).resolves.toEqual({
      accessVersion: 1,
      permissions: [],
      roles: [R],
      subscription: { plan: "pro" },
    })
  })

  it("returns null when session or user calls fail", async () => {
    createServerAuthClientMock.mockResolvedValue({
      auth: {
        getSession: vi.fn(() => {
          throw new Error("boom")
        }),
        getUser: vi.fn(() => {
          throw new Error("boom")
        }),
      },
    })

    await expect(getSession()).resolves.toBeNull()
    await expect(getUser()).resolves.toBeNull()
  })

  it("redirects unauthenticated users and returns claims for authenticated users", async () => {
    getClaimsMock.mockResolvedValueOnce(null)
    getRequestUrlMock.mockResolvedValue("http://localhost:3000/account")

    await expect(requireUser()).rejects.toThrow(
      "REDIRECT:sign-in:http://localhost:3000/account"
    )

    getClaimsMock.mockResolvedValueOnce({
      sub: "user-1",
    })

    await expect(requireUser()).resolves.toMatchObject({ sub: "user-1" })
  })
})
