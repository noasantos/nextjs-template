/**
 * Unit tests for usePsychologistAssistantsMutation
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { assistantsQueryKeys } from "@workspace/supabase-data/hooks/assistants/query-keys.codegen"
import { usePsychologistAssistantsMutation } from "@workspace/supabase-data/hooks/assistants/use-psychologist-assistants-mutation.hook.codegen"

describe("usePsychologistAssistantsMutation", () => {
  it("should export the generated hook", () => {
    expect(usePsychologistAssistantsMutation).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(assistantsQueryKeys.psychologistAssistants()).toBeDefined()
  })
})
