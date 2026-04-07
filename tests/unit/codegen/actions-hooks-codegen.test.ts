import { mkdtempSync, readFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { afterEach, describe, expect, it } from "vitest"

import { runActionsHooksCodegen } from "../../../scripts/codegen/actions-hooks-codegen"

const testFileDir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(testFileDir, "../../..")

describe("actions-hooks-codegen", () => {
  const tempDirs: string[] = []

  afterEach(() => {
    for (const dir of tempDirs.splice(0)) {
      rmSync(dir, { force: true, recursive: true })
    }
  })

  describe("runActionsHooksCodegen", () => {
    it("should return ok: true when codegen succeeds in check mode", () => {
      const result = runActionsHooksCodegen({
        repoRoot,
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
        repoRoot,
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
        repoRoot,
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
        repoRoot,
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
        repoRoot,
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
        repoRoot,
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/repository-plan.example.json",
        domainMapPath: "config/domain-map.example.json",
        checkOnly: true,
      })

      expect(Array.isArray(result.filesWritten)).toBe(true)
    })

    it("should report query keys update count", () => {
      const result = runActionsHooksCodegen({
        repoRoot,
        typesPath: "packages/codegen-tools/fixtures/database.types.mock.ts",
        planPath: "config/repository-plan.example.json",
        domainMapPath: "config/domain-map.example.json",
        checkOnly: true,
      })

      expect(typeof result.queryKeysUpdated).toBe("number")
    })

    it("should annotate generated update actions for type-escape checks", () => {
      const tempRepoRoot = mkdtempSync(join(tmpdir(), "actions-hooks-codegen-"))
      tempDirs.push(tempRepoRoot)

      const result = runActionsHooksCodegen({
        repoRoot: tempRepoRoot,
        typesPath: join(repoRoot, "packages/codegen-tools/fixtures/database.types.mock.ts"),
        planPath: join(repoRoot, "config/repository-plan.example.json"),
        domainMapPath: join(repoRoot, "config/domain-map.example.json"),
        checkOnly: false,
      })

      expect(result.ok).toBe(true)

      const actionPath = join(
        tempRepoRoot,
        "packages/supabase-data/src/actions/demo/demo-widgets-update.codegen.ts"
      )
      const content = readFileSync(actionPath, "utf8")

      expect(content).toContain(
        "// @type-escape: generated action stub — id shape from validated after TODO input schema"
      )
      expect(content).toContain("const validatedId = (validated as unknown as { id: string }).id")
      expect(content).toContain(
        "// @type-escape: generated action stub — update patch unknown until TODO input schema"
      )
      expect(content).toContain("const validatedPatch = validated as never")
      expect(content).toContain(
        "const result = await repository.update(validatedId, validatedPatch)"
      )
    })

    it("should place swallowExpectedError at module scope in generated tests", () => {
      const tempRepoRoot = mkdtempSync(join(tmpdir(), "actions-hooks-codegen-"))
      tempDirs.push(tempRepoRoot)

      const result = runActionsHooksCodegen({
        repoRoot: tempRepoRoot,
        typesPath: join(repoRoot, "packages/codegen-tools/fixtures/database.types.mock.ts"),
        planPath: join(repoRoot, "config/repository-plan.example.json"),
        domainMapPath: join(repoRoot, "config/domain-map.example.json"),
        checkOnly: false,
      })

      expect(result.ok).toBe(true)

      const testPath = join(
        tempRepoRoot,
        "tests/unit/supabase-data/actions/demo/demo-widgets-update.codegen.test.ts"
      )
      const content = readFileSync(testPath, "utf8")

      expect(content).toContain("const swallowExpectedError = (): undefined => undefined")
      expect(content).toContain('describe("updateDemoWidgetsAction", () => {')
      expect(content.indexOf("const swallowExpectedError")).toBeLessThan(
        content.indexOf('describe("updateDemoWidgetsAction", () => {')
      )
    })
  })
})
