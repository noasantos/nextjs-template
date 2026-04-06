#!/usr/bin/env tsx
/**
 * Deterministic JSON payload for building config/repository-plan.json.
 *
 * **Primary workflow:** part of skill `repository-plan-autonomous-pipeline` — run
 * this command, then the agent (same session) does semantic analysis on the JSON
 * stdout + types, writes `config/repository-plan.json`, then
 * `pnpm codegen:repository-plan:validate --strict` and
 * `pnpm codegen:backend --plan ... --write --force`. No human gates; see
 * `skills/repository-plan-autonomous-pipeline/SKILL.md`.
 *
 * Usage:
 *   pnpm codegen:repository-plan:context
 *   pnpm codegen:repository-plan:context -- --types <path> --map <path> --domain catalog
 *   pnpm codegen:repository-plan:context -- --sync-hint   # append domain-map vs types diff text
 */
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { buildRepositoryPlanContext } from "../../packages/codegen-tools/src/build-repository-plan-context.ts"
import { parseDomainMapJson } from "../../packages/codegen-tools/src/domain-map-schema.ts"
import { buildDomainMapSyncReport } from "../../packages/codegen-tools/src/sync-domain-map-report.ts"
import { resolveDomainMapPath } from "./config-defaults.ts"

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
const mapPath = resolveDomainMapPath(repoRoot, argValue("--map"))
const domainFilter = argValue("--domain")
const tableFilter = argValue("--table")
const syncHint = process.argv.includes("--sync-hint")

if (!mapPath) {
  process.stderr.write(
    "Missing domain map: copy config/domain-map.example.json to config/domain-map.json or pass --map\n"
  )
  process.exit(1)
}

const typesSource = readFileSync(typesPath, "utf8")
const mapRaw = JSON.parse(readFileSync(mapPath, "utf8")) as unknown
const domainMap = parseDomainMapJson(mapRaw)

let syncReportText: string | undefined
if (syncHint) {
  syncReportText = buildDomainMapSyncReport(domainMap, typesSource).text
}

const json = buildRepositoryPlanContext({
  databaseTypesSource: typesSource,
  domainMap,
  filterDomainId: domainFilter,
  filterTable: tableFilter,
  syncReportText,
})

process.stdout.write(`${json}\n`)
