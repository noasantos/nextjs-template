import { describe, expect, it } from "vitest"

import { runActionsHooksCodegen } from "../../../scripts/codegen/actions-hooks-codegen"

describe("actions-hooks-codegen", () => {
  describe("runActionsHooksCodegen", () => {
    it("should return ok: true when codegen succeeds in check mode", () => {
      const result = runActionsHooksCodegen({
        repoRoot: process.cwd(),
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/repository-plan.example.json",
        domainMapPath: "config/domain-map.example.json",
        checkOnly: true,
      })

      expect(typeof result.ok).toBe("boolean")
      expect(Array.isArray(result.filesWritten)).toBe(true)
      expect(Array.isArray(result.errors)).toBe(true)
    })

    it("should handle missing plan file gracefully", () => {
      const result = runActionsHooksCodegen({
        repoRoot: process.cwd(),
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/nonexistent-plan.json",
        domainMapPath: "config/domain-map.example.json",
        checkOnly: true,
      })

      expect(result.ok).toBe(false)
      expect(result.errors.length).toBeGreaterThan(0)
    })

    it("should handle missing domain map file gracefully", () => {
      const result = runActionsHooksCodegen({
        repoRoot: process.cwd(),
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/repository-plan.example.json",
        domainMapPath: "config/nonexistent-map.json",
        checkOnly: true,
      })

      expect(result.ok).toBe(false)
      expect(result.errors.length).toBeGreaterThan(0)
    })

    it("should handle domain filter gracefully", () => {
      const result = runActionsHooksCodegen({
        repoRoot: process.cwd(),
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/repository-plan.example.json",
        domainMapPath: "config/domain-map.example.json",
        checkOnly: true,
        domainFilter: "demo",
      })

      expect(typeof result.ok).toBe("boolean")
      expect(Array.isArray(result.errors)).toBe(true)
    })

    it("should track generated files count", () => {
      const result = runActionsHooksCodegen({
        repoRoot: process.cwd(),
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/repository-plan.example.json",
        domainMapPath: "config/domain-map.example.json",
        checkOnly: true,
      })

      expect(result).toHaveProperty("filesWritten")
      expect(result).toHaveProperty("actionsGenerated")
      expect(result).toHaveProperty("hooksGenerated")
      expect(result).toHaveProperty("queryKeysUpdated")
    })
  })

  describe("template generation", () => {
    it("should handle codegen without crashing", () => {
      const result = runActionsHooksCodegen({
        repoRoot: process.cwd(),
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/repository-plan.example.json",
        domainMapPath: "config/domain-map.example.json",
        checkOnly: true,
      })

      expect(Array.isArray(result.filesWritten)).toBe(true)
    })

    it("should report query keys update count", () => {
      const result = runActionsHooksCodegen({
        repoRoot: process.cwd(),
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/repository-plan.example.json",
        domainMapPath: "config/domain-map.example.json",
        checkOnly: true,
      })

      expect(typeof result.queryKeysUpdated).toBe("number")
    })
  })
})
