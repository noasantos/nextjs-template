/**
 * Unit tests for usePsychologistPreferencesAuditLogQuery
 *
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { auditQueryKeys } from "@workspace/supabase-data/hooks/audit/query-keys.codegen"
import { usePsychologistPreferencesAuditLogQuery } from "@workspace/supabase-data/hooks/audit/use-psychologist-preferences-audit-log-query.hook.codegen"

describe("usePsychologistPreferencesAuditLogQuery", () => {
  it("should export the generated hook", () => {
    expect(usePsychologistPreferencesAuditLogQuery).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(auditQueryKeys.psychologistPreferencesAuditLogList({})).toBeDefined()
  })
})
