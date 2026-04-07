import { describe, expect, it } from "vitest"

import {
  planDtoBasename,
  planDtoImportSpecifier,
  planMapperBasename,
  planMapperImportSpecifier,
  planModuleEntityKebab,
  planPortBasename,
  planPortImportSpecifier,
  planRepositoryBasename,
  planRepositoryImportSpecifier,
  planRepositoryIntegrationTestBasename,
  SUPABASE_DATA_MODULES_IMPORT_PREFIX,
} from "../../../packages/codegen-tools/src/backend-codegen/plan-module-paths"

describe("plan-module-paths", () => {
  it("maps table snake_case to entity kebab", () => {
    expect(planModuleEntityKebab("session_types")).toBe("session-types")
  })

  it("keeps basenames aligned with import specifiers (no .ts in imports)", () => {
    const domain = "catalog"
    const entity = "session-types"
    expect(planDtoBasename(entity)).toBe("session-types.dto.codegen.ts")
    expect(planDtoImportSpecifier(domain, entity)).toBe(
      `${SUPABASE_DATA_MODULES_IMPORT_PREFIX}/catalog/domain/dto/session-types.dto.codegen`
    )
    expect(planMapperBasename(entity)).toBe("session-types.mapper.codegen.ts")
    expect(planMapperImportSpecifier(domain, entity)).toBe(
      `${SUPABASE_DATA_MODULES_IMPORT_PREFIX}/catalog/infrastructure/mappers/session-types.mapper.codegen`
    )
    expect(planPortBasename(entity)).toBe("session-types-repository.port.codegen.ts")
    expect(planPortImportSpecifier(domain, entity)).toBe(
      `${SUPABASE_DATA_MODULES_IMPORT_PREFIX}/catalog/domain/ports/session-types-repository.port.codegen`
    )
    expect(planRepositoryBasename(entity)).toBe("session-types-supabase.repository.codegen.ts")
    expect(planRepositoryImportSpecifier(domain, entity)).toBe(
      `${SUPABASE_DATA_MODULES_IMPORT_PREFIX}/catalog/infrastructure/repositories/session-types-supabase.repository.codegen`
    )
    expect(planRepositoryIntegrationTestBasename(entity)).toBe(
      "session-types.repository.codegen.integration.test.ts"
    )
  })
})
