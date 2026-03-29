import { afterEach, describe, expect, it, vi } from "vitest"

const { createClientMock, getSupabaseServerEnvMock } = vi.hoisted(() => ({
  createClientMock: vi.fn(),
  getSupabaseServerEnvMock: vi.fn(),
}))

vi.mock("@supabase/supabase-js", () => ({
  createClient: createClientMock,
}))

vi.mock("@workspace/supabase-infra/env/server", () => ({
  getSupabaseServerEnv: getSupabaseServerEnvMock,
}))

import { createAdminClient } from "@workspace/supabase-infra/clients/create-admin-client"

afterEach(() => {
  createClientMock.mockReset()
  getSupabaseServerEnvMock.mockReset()
})

describe("createAdminClient", () => {
  it("creates a non-persistent service-role client", () => {
    getSupabaseServerEnvMock.mockReturnValue({
      authAllowedRedirectOrigins: ["http://127.0.0.1:3000"],
      authAppUrl: "http://127.0.0.1:3000",
      serviceRoleKey: "service-role-key",
      supabasePublishableKey: "anon-key",
      supabaseUrl: "http://127.0.0.1:54321",
    })
    createClientMock.mockReturnValue({ client: "admin" })

    const client = createAdminClient()

    expect(client).toEqual({ client: "admin" })
    expect(createClientMock).toHaveBeenCalledWith(
      "http://127.0.0.1:54321",
      "service-role-key",
      {
        auth: {
          autoRefreshToken: false,
          detectSessionInUrl: false,
          persistSession: false,
        },
      }
    )
  })
})
