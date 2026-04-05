import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { describe, expect, it } from "vitest"

import { validateDomainMapContent } from "../../../packages/codegen-tools/src/validate-domain-map.ts"

const dir = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(dir, "../../..")
const fixtureTypes = join(repoRoot, "packages/codegen-tools/fixtures/database.types.mock.ts")

/** Domain map derived from `database.types.mock.ts` public.Tables — not checked in as JSON. */
function domainMapForMockTypes() {
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

describe("validateDomainMapContent", () => {
  it("accepts an in-test domain map built from fixture database types", () => {
    const typesSource = readFileSync(fixtureTypes, "utf8")
    const mapRaw = domainMapForMockTypes()
    const result = validateDomainMapContent(mapRaw, typesSource)
    expect(result.ok).toBe(true)
    expect(result.errors).toEqual([])
  })

  it("rejects unknown table in domain", () => {
    const typesSource = readFileSync(fixtureTypes, "utf8")
    const mapRaw = {
      version: 1,
      domains: [{ id: "victicio", tables: ["demo_widgets", "does_not_exist"] }],
      ignoreTables: [],
    }
    const result = validateDomainMapContent(mapRaw, typesSource)
    expect(result.ok).toBe(false)
    expect(result.errors.some((e) => e.includes("does_not_exist"))).toBe(true)
  })
})
