/**
 * Unit tests for useBusySlotsQuery
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { calendarQueryKeys } from "@workspace/supabase-data/hooks/calendar/query-keys.codegen"
import { useBusySlotsQuery } from "@workspace/supabase-data/hooks/calendar/use-busy-slots-query.hook.codegen"

describe("useBusySlotsQuery", () => {
  it("should export the generated hook", () => {
    expect(useBusySlotsQuery).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(calendarQueryKeys.busySlotsList({})).toBeDefined()
  })
})
