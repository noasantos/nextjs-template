/**
 * Unit tests for usePsychologistOnboardingStateMutation
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { onboardingQueryKeys } from "@workspace/supabase-data/hooks/onboarding/query-keys.codegen"
import { usePsychologistOnboardingStateMutation } from "@workspace/supabase-data/hooks/onboarding/use-psychologist-onboarding-state-mutation.hook.codegen"

describe("usePsychologistOnboardingStateMutation", () => {
  it("should export the generated hook", () => {
    expect(usePsychologistOnboardingStateMutation).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(onboardingQueryKeys.psychologistOnboardingState()).toBeDefined()
  })
})
