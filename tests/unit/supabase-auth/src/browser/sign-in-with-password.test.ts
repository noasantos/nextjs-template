import { afterEach, describe, expect, it, vi } from "vitest"

const { createBrowserAuthClientMock, signInWithPasswordMock } = vi.hoisted(() => ({
  createBrowserAuthClientMock: vi.fn(),
  signInWithPasswordMock: vi.fn(),
}))

vi.mock("@workspace/supabase-auth/browser/create-browser-auth-client", () => ({
  createBrowserAuthClient: createBrowserAuthClientMock,
}))

import { signInWithPassword } from "@workspace/supabase-auth/browser/sign-in-with-password"

afterEach(() => {
  createBrowserAuthClientMock.mockReset()
  signInWithPasswordMock.mockReset()
})

describe("signInWithPassword", () => {
  it("forwards credentials to the browser auth client", async () => {
    createBrowserAuthClientMock.mockReturnValue({
      auth: {
        signInWithPassword: signInWithPasswordMock,
      },
    })
    signInWithPasswordMock.mockResolvedValue({ data: {}, error: null })

    await expect(
      signInWithPassword({
        email: "user@example.test",
        password: "Password123!",
      })
    ).resolves.toEqual({ data: {}, error: null })

    expect(signInWithPasswordMock).toHaveBeenCalledWith({
      email: "user@example.test",
      password: "Password123!",
    })
  })
})
