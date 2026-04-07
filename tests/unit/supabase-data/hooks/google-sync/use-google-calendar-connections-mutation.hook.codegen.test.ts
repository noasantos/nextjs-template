/**
 * Unit tests for useGoogleCalendarConnectionsMutation
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { googleSyncQueryKeys } from "@workspace/supabase-data/hooks/google-sync/query-keys.codegen"
import { useGoogleCalendarConnectionsMutation } from "@workspace/supabase-data/hooks/google-sync/use-google-calendar-connections-mutation.hook.codegen"

describe("useGoogleCalendarConnectionsMutation", () => {
  it("should export the generated hook", () => {
    expect(useGoogleCalendarConnectionsMutation).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(googleSyncQueryKeys.googleCalendarConnections()).toBeDefined()
  })
})
