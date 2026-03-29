import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

const { execFileSyncMock } = vi.hoisted(() => ({
  execFileSyncMock: vi.fn(),
}))

vi.mock("node:child_process", () => ({
  execFileSync: execFileSyncMock,
}))

beforeEach(() => {
  vi.resetModules()
})

afterEach(() => {
  execFileSyncMock.mockReset()
  vi.unstubAllEnvs()
})

describe("resolveServiceRoleKeyWhenUnset", () => {
  it("returns the explicit environment variable when present", async () => {
    vi.stubEnv("SUPABASE_SERVICE_ROLE_KEY", "service-role-key")

    const { resolveServiceRoleKeyWhenUnset } =
      await import("@workspace/supabase-infra/env/resolve-service-role-key")

    expect(resolveServiceRoleKeyWhenUnset()).toBe("service-role-key")
  })

  it("falls back to `supabase status -o env` in local development", async () => {
    execFileSyncMock.mockReturnValue('SERVICE_ROLE_KEY="cli-key"\n')

    const { resolveServiceRoleKeyWhenUnset } =
      await import("@workspace/supabase-infra/env/resolve-service-role-key")

    expect(resolveServiceRoleKeyWhenUnset()).toBe("cli-key")
    expect(execFileSyncMock).toHaveBeenCalledWith(
      "pnpm",
      ["exec", "supabase", "status", "-o", "env"],
      expect.objectContaining({
        encoding: "utf8",
      })
    )
  })

  it("throws in production-like environments when the variable is unset", async () => {
    vi.stubEnv("NODE_ENV", "production")

    const { resolveServiceRoleKeyWhenUnset } =
      await import("@workspace/supabase-infra/env/resolve-service-role-key")

    expect(() => resolveServiceRoleKeyWhenUnset()).toThrow(
      "Missing required environment variable: SUPABASE_SERVICE_ROLE_KEY"
    )
  })

  it("throws a local setup error when the CLI cannot resolve the key", async () => {
    execFileSyncMock.mockImplementation(() => {
      throw new Error("supabase not running")
    })

    const { resolveServiceRoleKeyWhenUnset } =
      await import("@workspace/supabase-infra/env/resolve-service-role-key")

    expect(() => resolveServiceRoleKeyWhenUnset()).toThrow(
      "Missing SUPABASE_SERVICE_ROLE_KEY"
    )
  })
})
