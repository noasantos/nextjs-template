/**
 * Unit tests for useCalendarChangeLogMutation
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { calendarQueryKeys } from "@workspace/supabase-data/hooks/calendar/query-keys.codegen"
import { useCalendarChangeLogMutation } from "@workspace/supabase-data/hooks/calendar/use-calendar-change-log-mutation.hook.codegen"

describe("useCalendarChangeLogMutation", () => {
  it("should export the generated hook", () => {
    expect(useCalendarChangeLogMutation).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(calendarQueryKeys.calendarChangeLog()).toBeDefined()
  })
})
