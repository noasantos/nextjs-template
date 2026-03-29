import { afterEach, describe, expect, it, vi } from "vitest"

const { createServerAuthClientMock, headersMock } = vi.hoisted(() => ({
  createServerAuthClientMock: vi.fn(),
  headersMock: vi.fn(),
}))

vi.mock("@workspace/supabase-auth/server/create-server-auth-client", () => ({
  createServerAuthClient: createServerAuthClientMock,
}))

vi.mock("next/headers", () => ({
  headers: headersMock,
}))

import { exchangeCodeForSession } from "@workspace/supabase-auth/server/exchange-code-for-session"
import { getRequestUrl } from "@workspace/supabase-auth/server/get-request-url"
import { verifyOtp } from "@workspace/supabase-auth/server/verify-otp"

afterEach(() => {
  createServerAuthClientMock.mockReset()
  headersMock.mockReset()
})

describe("server auth actions", () => {
  it("forwards code exchange and OTP verification to the server client", async () => {
    const exchangeCodeForSessionMock = vi.fn()
    const verifyOtpMock = vi.fn()

    createServerAuthClientMock.mockResolvedValue({
      auth: {
        exchangeCodeForSession: exchangeCodeForSessionMock,
        verifyOtp: verifyOtpMock,
      },
    })
    exchangeCodeForSessionMock.mockResolvedValue({ data: {}, error: null })
    verifyOtpMock.mockResolvedValue({ data: {}, error: null })

    await expect(exchangeCodeForSession("code-123")).resolves.toEqual({
      data: {},
      error: null,
    })
    await expect(
      verifyOtp({
        tokenHash: "token-hash",
        type: "recovery",
      })
    ).resolves.toEqual({
      data: {},
      error: null,
    })
  })

  it("reads the request URL header", async () => {
    headersMock.mockResolvedValue(
      new Headers([["x-app-request-url", "http://localhost:3000/account"]])
    )

    await expect(getRequestUrl()).resolves.toBe("http://localhost:3000/account")
  })
})
