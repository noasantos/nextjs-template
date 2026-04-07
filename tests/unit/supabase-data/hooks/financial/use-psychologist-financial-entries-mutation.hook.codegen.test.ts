/**
 * Unit tests for usePsychologistFinancialEntriesMutation
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { financialQueryKeys } from "@workspace/supabase-data/hooks/financial/query-keys.codegen"
import { usePsychologistFinancialEntriesMutation } from "@workspace/supabase-data/hooks/financial/use-psychologist-financial-entries-mutation.hook.codegen"

describe("usePsychologistFinancialEntriesMutation", () => {
  it("should export the generated hook", () => {
    expect(usePsychologistFinancialEntriesMutation).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(financialQueryKeys.psychologistFinancialEntries()).toBeDefined()
  })
})
