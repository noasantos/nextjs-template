import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

import { describe, expect, it } from "vitest"

import { extractPublicViewNames } from "../../../packages/codegen-tools/src/extract-public-view-names.ts"

const dir = dirname(fileURLToPath(import.meta.url))
const repoRoot = join(dir, "../../..")
const fixtureTypes = join(repoRoot, "packages/codegen-tools/fixtures/database.types.mock.ts")

describe("extractPublicViewNames", () => {
  it("reads view keys from fixture Database type", () => {
    const src = readFileSync(fixtureTypes, "utf8")
    const views = extractPublicViewNames(src)
    expect(views).toContain("demo_widgets_ro")
  })
})
