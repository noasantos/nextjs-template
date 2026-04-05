#!/usr/bin/env tsx
/**
 * Reports tables added/removed vs domain-map.json (no writes).
 */
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { parseDomainMapJson } from "../../packages/codegen-tools/src/domain-map-schema.ts"
import { buildDomainMapSyncReport } from "../../packages/codegen-tools/src/sync-domain-map-report.ts"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")

function argValue(flag: string): string | undefined {
  const i = process.argv.indexOf(flag)
  if (i === -1 || !process.argv[i + 1]) {
    return undefined
  }
  return process.argv[i + 1]
}

const typesPath =
  argValue("--types") ?? resolve(repoRoot, "packages/supabase-infra/src/types/database.types.ts")
const mapPath = argValue("--map") ?? resolve(repoRoot, "config/domain-map.json")

const typesSource = readFileSync(typesPath, "utf8")
const domainMap = parseDomainMapJson(JSON.parse(readFileSync(mapPath, "utf8")) as unknown)

const report = buildDomainMapSyncReport(domainMap, typesSource)
process.stdout.write(`${report.text}\n`)
