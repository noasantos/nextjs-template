/**
 * Server gate for a **single permission code** (must be listed in `AUTH_PERMISSIONS`).
 *
 * @see PERMISSIONS.exampleAccess — swap for your domain codes as you grow the matrix.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import { requirePermission } from "@workspace/supabase-auth/session/require-permission"
import { PERMISSIONS } from "@workspace/supabase-auth/shared/permission"
import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"

const { privilegedRole } = ACCESS_CONTROL_TEMPLATE

const {
  buildAuthAccessDeniedUrlMock,
  buildAuthSignInUrlMock,
  createServerAuthClientMock,
  getClaimsMock,
  getRequestUrlMock,
  redirectMock,
} = vi.hoisted(() => ({
  buildAuthAccessDeniedUrlMock: vi.fn(
    (redirectTo, required) =>
      `access-denied:${redirectTo}:${required?.join(",")}`
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

describe("requirePermission (single-code gate)", () => {
  it("accepts when JWT app_metadata.permissions includes the code", async () => {
    getClaimsMock.mockResolvedValue({
      app_metadata: { permissions: [PERMISSIONS.exampleAccess] },
      sub: "user-1",
    })

    await expect(
      requirePermission({ permission: PERMISSIONS.exampleAccess })
    ).resolves.toBeUndefined()
  })

  it("redirects when the code is missing (even if roles are present)", async () => {
    getClaimsMock.mockResolvedValue({
      app_metadata: { roles: [privilegedRole] },
      sub: "user-1",
    })

    await expect(
      requirePermission({ permission: PERMISSIONS.exampleAccess })
    ).rejects.toThrow(/^REDIRECT:/)

    expect(buildAuthAccessDeniedUrlMock).toHaveBeenCalled()
  })
})
