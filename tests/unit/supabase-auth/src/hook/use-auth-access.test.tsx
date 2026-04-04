/**
 * Client hook reads **`auth.getClaims()`** (same shape as hook-enriched JWT).
 *
 * @see ACCESS_CONTROL_TEMPLATE for example role / permission strings used across suites.
 */
import { renderHook, waitFor } from "@testing-library/react"
import { afterEach, describe, expect, it, vi } from "vitest"

import { useAuthAccess } from "@workspace/supabase-auth/hook/use-auth-access"
import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"

const { exampleJwtPermission: P, privilegedRole: R } = ACCESS_CONTROL_TEMPLATE

const { createBrowserAuthClientMock } = vi.hoisted(() => ({
  createBrowserAuthClientMock: vi.fn(),
}))

vi.mock("@workspace/supabase-auth/browser/create-browser-auth-client", () => ({
  createBrowserAuthClient: createBrowserAuthClientMock,
}))

afterEach(() => {
  createBrowserAuthClientMock.mockReset()
})

function createMockClient({ claims }: { claims: Record<string, unknown> | null }) {
  return {
    auth: {
      getClaims: vi.fn().mockResolvedValue({
        data: {
          claims,
        },
      }),
      onAuthStateChange: vi.fn().mockReturnValue({
        data: {
          subscription: {
            unsubscribe: vi.fn(),
          },
        },
      }),
      refreshSession: vi.fn().mockResolvedValue({ data: {}, error: null }),
    },
  }
}

describe("useAuthAccess (client claims contract)", () => {
  it("surfaces roles, permissions, and subscription from JWT claims", async () => {
    createBrowserAuthClientMock.mockReturnValue(
      createMockClient({
        claims: {
          app_metadata: {
            permissions: [P],
            roles: [R],
          },
          sub: "user-1",
        },
      })
    )

    const { result } = renderHook(() => useAuthAccess())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.roles).toEqual([R])
    expect(result.current.permissions).toEqual([P])
    expect(result.current.subscription).toEqual({})
  })

  it("defaults permissions to [] when the claim is absent", async () => {
    const client = createMockClient({
      claims: {
        app_metadata: {
          roles: [R],
        },
        sub: "user-1",
      },
    })

    createBrowserAuthClientMock.mockReturnValue(client)

    const { result } = renderHook(() => useAuthAccess())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.permissions).toEqual([])
    expect(result.current.roles).toEqual([R])
    expect(result.current.subscription).toEqual({})
  })
})
