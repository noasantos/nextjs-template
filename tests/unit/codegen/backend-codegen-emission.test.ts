import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { describe, expect, it } from "vitest"

import { runBackendCodegen } from "../../../packages/codegen-tools/src/backend-codegen.ts"
import { isCodegenManagedSource } from "../../../packages/codegen-tools/src/backend-codegen/constants.ts"
import { parseRepositoryPlanJson } from "../../../packages/codegen-tools/src/repository-plan-schema.ts"

const testDir = dirname(fileURLToPath(import.meta.url))
const repoFixtureRoot = join(testDir, "../../..")

describe("runBackendCodegen (plan emission)", () => {
  it("writes managed files and checkOnly passes on second run", () => {
    const repoRoot = mkdtempSync(join(tmpdir(), "codegen-emit-"))
    const typesPath = join(repoRoot, "database.types.ts")
    const mapPath = join(repoRoot, "domain-map.json")
    const planPath = join(repoRoot, "repository-plan.json")

    const fixtureTypes = readFileSync(
      join(repoFixtureRoot, "packages/codegen-tools/fixtures/database.types.mock.ts"),
      "utf8"
    )
    writeFileSync(typesPath, fixtureTypes, "utf8")

    writeFileSync(
      mapPath,
      JSON.stringify(
        {
          version: 1,
          domains: [
            {
              id: "victicio",
              codegen: true,
              exposeActions: true,
              readOnly: false,
              tables: ["demo_widgets"],
            },
          ],
          ignoreTables: [],
        },
        null,
        2
      ),
      "utf8"
    )

    const plan = parseRepositoryPlanJson({
      version: 1,
      meta: { generatedAt: "2026-01-01T00:00:00.000Z", generator: "test" },
      entries: [
        {
          domainId: "victicio",
          table: "demo_widgets",
          read: { kind: "table", name: "demo_widgets" },
          methods: ["findById", "list"],
          dto: { style: "zod", include: "all_columns" },
        },
      ],
    })
    writeFileSync(planPath, `${JSON.stringify(plan, null, 2)}\n`, "utf8")

    mkdirSync(join(repoRoot, "packages", "supabase-data", "src", "modules"), { recursive: true })

    const first = runBackendCodegen({
      checkOnly: false,
      domainMapPath: mapPath,
      repoRoot,
      typesPath,
      planPath,
      force: true,
    })
    expect(first.ok).toBe(true)
    expect(first.filesWritten.length).toBeGreaterThan(0)

    const repoFile = join(
      repoRoot,
      "packages/supabase-data/src/modules/victicio/infrastructure/repositories/demo-widgets-supabase.repository.codegen.ts"
    )
    const disk = readFileSync(repoFile, "utf8")
    expect(isCodegenManagedSource(disk)).toBe(true)

    const second = runBackendCodegen({
      checkOnly: true,
      domainMapPath: mapPath,
      repoRoot,
      typesPath,
      planPath,
      force: false,
    })
    expect(second.ok).toBe(true)

    rmSync(repoRoot, { recursive: true, force: true })
  })
})
