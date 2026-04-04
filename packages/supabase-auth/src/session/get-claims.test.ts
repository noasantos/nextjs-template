import { afterEach, describe, expect, it, vi } from "vitest"

const { createServerAuthClientMock } = vi.hoisted(() => ({
  createServerAuthClientMock: vi.fn(),
}))
const { logServerEventMock } = vi.hoisted(() => ({
  logServerEventMock: vi.fn(),
}))

vi.mock("@workspace/supabase-auth/server/create-server-auth-client", () => ({
  createServerAuthClient: createServerAuthClientMock,
}))
vi.mock("@workspace/logging/server", () => ({
  logServerEvent: logServerEventMock,
}))

vi.mock("next/navigation", () => ({
  unstable_rethrow: (error: unknown) => {
    if (
      typeof error === "object" &&
      error !== null &&
      "digest" in error &&
      typeof (error as { digest: unknown }).digest === "string" &&
      (error as { digest: string }).digest === "DYNAMIC_SERVER_USAGE"
    ) {
      throw error
    }
  },
}))

import { getClaims } from "@workspace/supabase-auth/session/get-claims"

afterEach(() => {
  createServerAuthClientMock.mockReset()
  logServerEventMock.mockReset()
})

describe("getClaims", () => {
  it("returns claims from the auth client", async () => {
    createServerAuthClientMock.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: {
            claims: { role: "admin", sub: "user-1" },
          },
        }),
      },
    })

    await expect(getClaims()).resolves.toEqual({
      role: "admin",
      sub: "user-1",
    })
  })

  it("returns null when the auth client has no claims", async () => {
    createServerAuthClientMock.mockResolvedValue({
      auth: {
        getClaims: vi.fn().mockResolvedValue({
          data: {
            claims: null,
          },
        }),
      },
    })

    await expect(getClaims()).resolves.toBeNull()
  })

  it("rethrows Next.js dynamic rendering bailout without logging", async () => {
    const dynamicUsage = Object.assign(new Error("Dynamic server usage: cookies"), {
      digest: "DYNAMIC_SERVER_USAGE" as const,
    })
    createServerAuthClientMock.mockRejectedValue(dynamicUsage)

    await expect(getClaims()).rejects.toBe(dynamicUsage)
    expect(logServerEventMock).not.toHaveBeenCalled()
  })

  it("logs and returns null on real integration errors", async () => {
    createServerAuthClientMock.mockRejectedValue(new Error("jwks unreachable"))

    await expect(getClaims()).resolves.toBeNull()
    expect(logServerEventMock).toHaveBeenCalledTimes(1)
    expect(logServerEventMock.mock.calls[0]?.[0]).toMatchObject({
      eventName: "claims_lookup_failed",
      outcome: "failure",
    })
  })
})
