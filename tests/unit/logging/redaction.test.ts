import { describe, expect, it, vi } from "vitest"

import {
  getIpAddressFromHeaders,
  hashDeterministic,
  sanitizeMetadata,
  sanitizeRequestPath,
} from "@workspace/logging/redaction"

describe("redaction helpers", () => {
  it("redacts sensitive metadata keys recursively", () => {
    expect(
      sanitizeMetadata({
        email: "user@example.test",
        nested: {
          authorization: "Bearer abc",
          safe: "value",
        },
      })
    ).toEqual({
      email: "[REDACTED]",
      nested: {
        authorization: "[REDACTED]",
        safe: "value",
      },
    })
  })

  it("hashes identifiers deterministically", async () => {
    vi.stubEnv("OBSERVABILITY_HASH_SECRET", "test-secret")

    await expect(hashDeterministic("user-1")).resolves.toBe(
      await hashDeterministic("user-1")
    )
  })

  it("normalizes request details", () => {
    const headers = new Headers({
      "x-forwarded-for": "192.168.1.10, 10.0.0.2",
    })

    expect(getIpAddressFromHeaders(headers)).toBe("192.168.1.10")
    expect(
      sanitizeRequestPath("https://example.test/auth/callback?token=secret")
    ).toBe("/auth/callback")
  })
})
