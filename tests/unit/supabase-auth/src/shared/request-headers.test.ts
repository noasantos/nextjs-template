import { describe, expect, it } from "vitest"

import { LOG_REQUEST_URL_HEADER } from "@workspace/supabase-auth/shared/request-headers"

describe("request headers", () => {
  it("uses the canonical request URL header name", () => {
    expect(LOG_REQUEST_URL_HEADER).toBe("x-app-request-url")
  })
})
