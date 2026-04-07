/**
 * Unit tests for useAssistantInvitesQuery
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { assistantsQueryKeys } from "@workspace/supabase-data/hooks/assistants/query-keys.codegen"
import { useAssistantInvitesQuery } from "@workspace/supabase-data/hooks/assistants/use-assistant-invites-query.hook.codegen"

describe("useAssistantInvitesQuery", () => {
  it("should export the generated hook", () => {
    expect(useAssistantInvitesQuery).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(assistantsQueryKeys.assistantInvitesList({})).toBeDefined()
  })
})
