/**
 * Unit tests for usePsychologistServicesQuery
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { preferencesQueryKeys } from "@workspace/supabase-data/hooks/preferences/query-keys.codegen"
import { usePsychologistServicesQuery } from "@workspace/supabase-data/hooks/preferences/use-psychologist-services-query.hook.codegen"

describe("usePsychologistServicesQuery", () => {
  it("should export the generated hook", () => {
    expect(usePsychologistServicesQuery).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(preferencesQueryKeys.psychologistServicesList({})).toBeDefined()
  })
})
