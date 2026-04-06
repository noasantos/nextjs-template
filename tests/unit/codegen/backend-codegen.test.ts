import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { describe, expect, it } from "vitest"

import { runBackendCodegen } from "../../../packages/codegen-tools/src/backend-codegen.ts"

const testDir = dirname(fileURLToPath(import.meta.url))
const repoFixtureRoot = join(testDir, "../../..")

describe("runBackendCodegen (legacy stub)", () => {
  it("reports missing stub in checkOnly when no plan and file absent", () => {
    const repoRoot = mkdtempSync(join(tmpdir(), "codegen-legacy-"))
    const typesPath = join(repoRoot, "database.types.ts")
    const mapPath = join(repoRoot, "domain-map.json")

    writeFileSync(
      typesPath,
      readFileSync(
        join(repoFixtureRoot, "packages/codegen-tools/fixtures/database.types.mock.ts"),
        "utf8"
      ),
      "utf8"
    )
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

    const gen = runBackendCodegen({
      checkOnly: true,
      domainMapPath: mapPath,
      repoRoot,
      typesPath,
      mode: "legacy",
    })
    expect(gen.ok).toBe(false)
    expect(gen.errors.some((e) => e.includes("Missing generated repository"))).toBe(true)

    rmSync(repoRoot, { recursive: true, force: true })
  })
})
