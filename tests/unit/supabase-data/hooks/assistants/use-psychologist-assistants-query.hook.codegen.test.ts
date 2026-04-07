/**
 * Unit tests for usePsychologistAssistantsQuery
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { assistantsQueryKeys } from "@workspace/supabase-data/hooks/assistants/query-keys.codegen"
import { usePsychologistAssistantsQuery } from "@workspace/supabase-data/hooks/assistants/use-psychologist-assistants-query.hook.codegen"

describe("usePsychologistAssistantsQuery", () => {
  it("should export the generated hook", () => {
    expect(usePsychologistAssistantsQuery).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(assistantsQueryKeys.psychologistAssistantsList({})).toBeDefined()
  })
})
