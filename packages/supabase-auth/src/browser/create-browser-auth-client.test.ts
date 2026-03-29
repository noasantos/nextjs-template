import { afterEach, describe, expect, it, vi } from "vitest"

const { createBrowserClientMock, getSupabasePublicEnvMock } = vi.hoisted(
  () => ({
    createBrowserClientMock: vi.fn(),
    getSupabasePublicEnvMock: vi.fn(),
  })
)

vi.mock("@supabase/ssr", () => ({
  createBrowserClient: createBrowserClientMock,
}))

vi.mock("@workspace/supabase-infra/env/public", () => ({
  getSupabasePublicEnv: getSupabasePublicEnvMock,
}))

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

afterEach(() => {
  createBrowserClientMock.mockReset()
  getSupabasePublicEnvMock.mockReset()
})

describe("createBrowserAuthClient", () => {
  it("creates and memoizes the browser client", () => {
    getSupabasePublicEnvMock.mockReturnValue({
      authAllowedRedirectOrigins: ["http://localhost:3000"],
      authAppUrl: "http://localhost:3000",
      supabasePublishableKey: "anon-key",
      supabaseUrl: "http://localhost:54321",
    })
    createBrowserClientMock.mockReturnValue({ client: "supabase" })

    const first = createBrowserAuthClient()
    const second = createBrowserAuthClient()

    expect(first).toEqual({ client: "supabase" })
    expect(second).toBe(first)
    expect(createBrowserClientMock).toHaveBeenCalledTimes(1)
  })
})
