/**
 * Unit tests for useAssistantInvitesMutation
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { assistantsQueryKeys } from "@workspace/supabase-data/hooks/assistants/query-keys.codegen"
import { useAssistantInvitesMutation } from "@workspace/supabase-data/hooks/assistants/use-assistant-invites-mutation.hook.codegen"

describe("useAssistantInvitesMutation", () => {
  it("should export the generated hook", () => {
    expect(useAssistantInvitesMutation).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(assistantsQueryKeys.assistantInvites()).toBeDefined()
  })
})
