import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { describe, expect, it } from "vitest"

import { parseDomainMapJson } from "../../../packages/codegen-tools/src/domain-map-schema.ts"
import { mergeAndValidateRepositoryPlan } from "../../../packages/codegen-tools/src/merge-repository-plan.ts"
import { parseRepositoryPlanJson } from "../../../packages/codegen-tools/src/repository-plan-schema.ts"

const dir = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(dir, "../../..")
const fixtureTypes = join(repoRoot, "packages/codegen-tools/fixtures/database.types.mock.ts")

function domainMapForMock() {
  return {
    version: 1 as const,
    domains: [
      {
        auth: "session" as const,
        codegen: true,
        exposeActions: true,
        id: "victicio",
        readOnly: false,
        tables: ["demo_widgets", "demo_widget_events"],
      },
    ],
    ignoreTables: [] as string[],
  }
}

describe("mergeAndValidateRepositoryPlan", () => {
  it("accepts plan rows that match types and domain map", () => {
    const typesSource = readFileSync(fixtureTypes, "utf8")
    const domainMap = parseDomainMapJson(domainMapForMock())
    const plan = parseRepositoryPlanJson({
      version: 1,
      meta: { generatedAt: "2026-01-01T00:00:00.000Z", generator: "test" },
      entries: [
        {
          domainId: "victicio",
          table: "demo_widgets",
          read: { kind: "table", name: "demo_widgets" },
          methods: ["findById"],
          dto: { style: "zod", include: "all_columns" },
        },
      ],
    })
    const merged = mergeAndValidateRepositoryPlan({
      databaseTypesSource: typesSource,
      domainMap,
      plan,
      strict: false,
    })
    expect(merged.ok).toBe(true)
    expect(merged.entriesByKey.get("victicio::demo_widgets")).toBeDefined()
  })

  it("rejects readOnly domain with insert method", () => {
    const typesSource = readFileSync(fixtureTypes, "utf8")
    const domainMap = parseDomainMapJson({
      version: 1,
      domains: [
        {
          id: "ro",
          readOnly: true,
          tables: ["demo_widgets"],
        },
      ],
      ignoreTables: [],
    })
    const plan = parseRepositoryPlanJson({
      version: 1,
      meta: { generatedAt: "2026-01-01T00:00:00.000Z", generator: "test" },
      entries: [
        {
          domainId: "ro",
          table: "demo_widgets",
          read: { kind: "table", name: "demo_widgets" },
          methods: ["insert"],
          dto: { style: "zod", include: "all_columns" },
        },
      ],
    })
    const merged = mergeAndValidateRepositoryPlan({
      databaseTypesSource: typesSource,
      domainMap,
      plan,
      strict: false,
    })
    expect(merged.ok).toBe(false)
  })

  it("strict mode requires all codegen tables", () => {
    const typesSource = readFileSync(fixtureTypes, "utf8")
    const domainMap = parseDomainMapJson(domainMapForMock())
    const plan = parseRepositoryPlanJson({
      version: 1,
      meta: { generatedAt: "2026-01-01T00:00:00.000Z", generator: "test" },
      entries: [
        {
          domainId: "victicio",
          table: "demo_widgets",
          read: { kind: "table", name: "demo_widgets" },
          methods: ["findById"],
          dto: { style: "zod", include: "all_columns" },
        },
      ],
    })
    const merged = mergeAndValidateRepositoryPlan({
      databaseTypesSource: typesSource,
      domainMap,
      plan,
      strict: true,
    })
    expect(merged.ok).toBe(false)
    expect(merged.errors.some((e) => e.includes("missing entry"))).toBe(true)
  })
})
