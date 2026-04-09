import { NextRequest } from "next/server"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

const { createServerAuthClientMock, signOutMock } = vi.hoisted(() => ({
  createServerAuthClientMock: vi.fn(),
  signOutMock: vi.fn(),
}))

vi.mock("@workspace/supabase-auth/server/create-server-auth-client", () => ({
  createServerAuthClient: createServerAuthClientMock,
}))

import { GET } from "@/app/(auth-handlers)/logout/route"

beforeEach(() => {
  vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "http://localhost:3000")
  vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "pk")
  vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://localhost:54321")
  vi.stubEnv(
    "NEXT_PUBLIC_AUTH_ALLOWED_REDIRECT_ORIGINS",
    "http://localhost:3000,http://localhost:3001"
  )

  signOutMock.mockResolvedValue({ error: null })
  createServerAuthClientMock.mockResolvedValue({
    auth: {
      signOut: signOutMock,
    },
  })
})

afterEach(() => {
  vi.unstubAllEnvs()
  createServerAuthClientMock.mockReset()
  signOutMock.mockReset()
})

describe("auth logout route", () => {
  it("calls signOut on the server auth client", async () => {
    await GET(new NextRequest("http://localhost:3000/logout"))

    expect(createServerAuthClientMock).toHaveBeenCalledTimes(1)
    expect(signOutMock).toHaveBeenCalledTimes(1)
  })

  it("redirects to sign-in with signed_out when redirect_to is missing", async () => {
    const response = await GET(new NextRequest("http://localhost:3000/logout"))

    expect(response.headers.get("location")).toBe("http://localhost:3000/sign-in?auth=signed_out")
  })

  it("redirects to an allowed redirect_to origin", async () => {
    const response = await GET(
      new NextRequest(
        "http://localhost:3000/logout?redirect_to=http%3A%2F%2Flocalhost%3A3000%2Faccount"
      )
    )

    expect(response.headers.get("location")).toBe("http://localhost:3000/account")
  })

  it("falls back to safe sign-in when redirect_to is not an allowed origin", async () => {
    const response = await GET(
      new NextRequest("http://localhost:3000/logout?redirect_to=https%3A%2F%2Fevil.example%2Fsteal")
    )

    expect(response.headers.get("location")).toBe("http://localhost:3000/sign-in?auth=signed_out")
  })
})
