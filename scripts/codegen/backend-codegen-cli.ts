#!/usr/bin/env tsx
/**
 * Backend repository codegen (legacy stubs and/or plan-driven DTO/mapper/repo).
 *
 * Usage:
 *   pnpm codegen:backend --check
 *   pnpm codegen:backend --write
 *   pnpm codegen:backend --check --plan config/repository-plan.json --mode strict
 *   pnpm codegen:backend --write --domain catalog --table session_types --force
 */
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import {
  resolveRepoRoot,
  runBackendCodegen,
} from "../../packages/codegen-tools/src/backend-codegen.ts"
import { validateDomainMapContent } from "../../packages/codegen-tools/src/validate-domain-map.ts"
import { resolveDomainMapPath, resolveRepositoryPlanPath } from "./config-defaults.ts"

const repoRoot = resolveRepoRoot(resolve(dirname(fileURLToPath(import.meta.url)), "../.."))

function argValue(flag: string): string | undefined {
  const i = process.argv.indexOf(flag)
  if (i === -1 || !process.argv[i + 1]) {
    return undefined
  }
  return process.argv[i + 1]
}

const write = process.argv.includes("--write")
const checkOnly = process.argv.includes("--check") || !write
if (write && process.argv.includes("--check")) {
  process.stderr.write("Use either --check or --write, not both\n")
  process.exit(1)
}

const typesPath =
  argValue("--types") ?? resolve(repoRoot, "packages/supabase-infra/src/types/database.types.ts")
const mapPath = resolveDomainMapPath(repoRoot, argValue("--map"))
const planPath = resolveRepositoryPlanPath(repoRoot, argValue("--plan"))
const modeArg = argValue("--mode")
const mode = modeArg === "strict" ? "strict" : "legacy"
const domainFilter = argValue("--domain")
const tableFilter = argValue("--table")
const force = process.argv.includes("--force")

if (!mapPath) {
  process.stderr.write(
    "Missing domain map: copy config/domain-map.example.json to config/domain-map.json or pass --map\n"
  )
  process.exit(1)
}

const typesSource = readFileSync(typesPath, "utf8")
const mapRaw = JSON.parse(readFileSync(mapPath, "utf8")) as unknown

const validation = validateDomainMapContent(mapRaw, typesSource)
if (!validation.ok) {
  process.stderr.write("Fix domain-map before codegen:\n\n")
  for (const e of validation.errors) {
    process.stderr.write(`${e}\n`)
  }
  process.exit(1)
}

const gen = runBackendCodegen({
  checkOnly,
  domainMapPath: mapPath,
  repoRoot,
  typesPath,
  planPath,
  mode,
  filterDomainId: domainFilter,
  filterTable: tableFilter,
  force,
})

if (!gen.ok) {
  for (const e of gen.errors) {
    process.stderr.write(`${e}\n`)
  }
  process.exit(1)
}

if (write && gen.filesWritten.length > 0) {
  process.stdout.write(`Wrote ${gen.filesWritten.length} file(s):\n`)
  for (const f of gen.filesWritten) {
    process.stdout.write(`  ${f}\n`)
  }
  process.stdout.write(
    "\nAdd explicit package.json exports in @workspace/supabase-data for new modules.\n"
  )
} else if (checkOnly) {
  if (gen.codegenEnabledDomainCount === 0) {
    process.stdout.write(
      "codegen:backend --check OK (no work): every domain has codegen: false — " +
        "enable codegen: true on a domain to emit stubs, or use a workspace map for experiments " +
        "(see docs/guides/backend-codegen.md).\n"
    )
  } else {
    process.stdout.write("codegen:backend --check OK (all expected repository files exist).\n")
  }
} else {
  process.stdout.write("Nothing to generate.\n")
}
