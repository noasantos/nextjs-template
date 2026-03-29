import { afterEach, describe, expect, it, vi } from "vitest"

const { cookiesMock, createServerClientMock } = vi.hoisted(() => ({
  cookiesMock: vi.fn(),
  createServerClientMock: vi.fn(),
}))

vi.mock("next/headers", () => ({
  cookies: cookiesMock,
}))

vi.mock("@supabase/ssr", () => ({
  createServerClient: createServerClientMock,
}))

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"

afterEach(() => {
  cookiesMock.mockReset()
  createServerClientMock.mockReset()
  vi.unstubAllEnvs()
})

describe("createServerAuthClient", () => {
  it("creates a server auth client with the request cookies adapter", async () => {
    const set = vi.fn()
    const cookieStore = {
      getAll: vi.fn().mockReturnValue([{ name: "sb", value: "token" }]),
      set,
    }

    cookiesMock.mockResolvedValue(cookieStore)
    createServerClientMock.mockReturnValue({ client: "supabase" })
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "http://127.0.0.1:3000")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "anon-key")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321")

    const client = await createServerAuthClient()
    const call = createServerClientMock.mock.calls.at(0)

    expect(client).toEqual({ client: "supabase" })
    expect(call).toBeDefined()
    expect(createServerClientMock).toHaveBeenCalledWith(
      "http://127.0.0.1:54321",
      "anon-key",
      expect.any(Object)
    )
    const options = call![2]
    expect(options.cookies.getAll()).toEqual([{ name: "sb", value: "token" }])

    options.cookies.setAll([
      { name: "sb-access-token", options: { path: "/" }, value: "new-token" },
    ])

    expect(set).toHaveBeenCalledWith("sb-access-token", "new-token", {
      path: "/",
    })
  })

  it("swallows cookie write failures", async () => {
    const cookieStore = {
      getAll: vi.fn().mockReturnValue([]),
      set: vi.fn(() => {
        throw new Error("immutable cookies")
      }),
    }

    cookiesMock.mockResolvedValue(cookieStore)
    createServerClientMock.mockReturnValue({ client: "supabase" })
    vi.stubEnv("NEXT_PUBLIC_AUTH_APP_URL", "http://127.0.0.1:3000")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "anon-key")
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321")

    await createServerAuthClient()
    const call = createServerClientMock.mock.calls.at(0)

    expect(call).toBeDefined()
    const options = call![2]
    expect(() =>
      options.cookies.setAll([
        { name: "sb-refresh-token", options: { path: "/" }, value: "refresh" },
      ])
    ).not.toThrow()
  })
})
