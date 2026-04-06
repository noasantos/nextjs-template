#!/usr/bin/env tsx
/**
 * Validates repository plan JSON (Zod + merge against domain-map + database types).
 *
 * Default paths: `config/repository-plan.json` if present, else
 * `config/repository-plan.example.json` (committed template). Same for `--map` /
 * domain-map.
 *
 * Usage:
 *   pnpm codegen:repository-plan:validate
 *   pnpm codegen:repository-plan:validate -- --plan path/to/plan.json --strict
 *
 * If no plan file exists (neither local nor example), exits 0 (nothing to validate).
 */
import { existsSync, readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { parseDomainMapJson } from "../../packages/codegen-tools/src/domain-map-schema.ts"
import { mergeAndValidateRepositoryPlan } from "../../packages/codegen-tools/src/merge-repository-plan.ts"
import { parseRepositoryPlanJson } from "../../packages/codegen-tools/src/repository-plan-schema.ts"
import { resolveDomainMapPath, resolveRepositoryPlanPath } from "./config-defaults.ts"

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
const planPath = resolveRepositoryPlanPath(repoRoot, argValue("--plan"))
const strict = process.argv.includes("--strict")

if (!planPath || !existsSync(planPath)) {
  process.stdout.write(
    "Skip: no repository plan (neither config/repository-plan.json nor config/repository-plan.example.json); pass --plan to validate a specific file.\n"
  )
  process.exit(0)
}

if (!mapPath || !existsSync(mapPath)) {
  process.stderr.write(
    "Missing domain map: copy config/domain-map.example.json to config/domain-map.json or pass --map\n"
  )
  process.exit(1)
}

const typesSource = readFileSync(typesPath, "utf8")
const mapRaw = JSON.parse(readFileSync(mapPath, "utf8")) as unknown
const planRaw = JSON.parse(readFileSync(planPath, "utf8")) as unknown

const domainMap = parseDomainMapJson(mapRaw)
const plan = parseRepositoryPlanJson(planRaw)

const merged = mergeAndValidateRepositoryPlan({
  databaseTypesSource: typesSource,
  domainMap,
  plan,
  strict,
})

if (!merged.ok) {
  process.stderr.write("repository-plan validation failed:\n\n")
  for (const e of merged.errors) {
    process.stderr.write(`${e}\n`)
  }
  process.exit(1)
}

process.stdout.write(`OK: ${planPath} (${plan.entries.length} entries)\n`)
