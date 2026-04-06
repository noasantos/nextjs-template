#!/usr/bin/env tsx
/**
 * Reports tables added/removed vs domain map (no writes).
 * Default map: `config/domain-map.json` if present, else `config/domain-map.example.json`.
 */
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

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

if (!mapPath) {
  process.stderr.write(
    "Missing domain map: copy config/domain-map.example.json to config/domain-map.json or pass --map\n"
  )
  process.exit(1)
}

const typesSource = readFileSync(typesPath, "utf8")
const domainMap = parseDomainMapJson(JSON.parse(readFileSync(mapPath, "utf8")) as unknown)

const report = buildDomainMapSyncReport(domainMap, typesSource)
process.stdout.write(`${report.text}\n`)
