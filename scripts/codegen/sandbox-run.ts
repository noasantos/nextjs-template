#!/usr/bin/env tsx
/**
 * Generates stub repository + port under packages/supabase-data/src/modules/codegen-sandbox/
 * using the real database.types.ts (table observability_events). Merges config/domain-map.json
 * in memory so production config is unchanged.
 *
 *   pnpm codegen:sandbox
 *
 * Remove output:
 *
 *   pnpm codegen:sandbox:clean
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { runBackendCodegen } from "../../packages/codegen-tools/src/backend-codegen.ts"
import {
  parseDomainMapJson,
  type DomainMapFile,
} from "../../packages/codegen-tools/src/domain-map-schema.ts"
import { validateDomainMapContent } from "../../packages/codegen-tools/src/validate-domain-map.ts"

const SANDBOX_DOMAIN_ID = "codegen-sandbox"
const SANDBOX_TABLE = "observability_events"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const configMapPath = join(repoRoot, "config/domain-map.json")
const typesPath = join(repoRoot, "packages/supabase-infra/src/types/database.types.ts")
const runtimeMapPath = join(
  repoRoot,
  "packages/codegen-tools/workspace/domain-map.sandbox-runtime.json"
)
const runtimePlanPath = join(
  repoRoot,
  "packages/codegen-tools/workspace/repository-plan.sandbox-runtime.json"
)

function buildSandboxDomainMap(base: DomainMapFile): DomainMapFile {
  const ignoreTables = (base.ignoreTables ?? []).filter((t) => t !== SANDBOX_TABLE)
  const domains = base.domains.filter((d) => d.id !== SANDBOX_DOMAIN_ID)

  return {
    version: 1,
    domains: [
      ...domains,
      {
        auth: "session",
        codegen: true,
        exposeActions: true,
        id: SANDBOX_DOMAIN_ID,
        readOnly: false,
        tables: [SANDBOX_TABLE],
      },
    ],
    ignoreTables,
  }
}

const typesSource = readFileSync(typesPath, "utf8")
const baseRaw = JSON.parse(readFileSync(configMapPath, "utf8")) as unknown
const baseMap = parseDomainMapJson(baseRaw)
const merged = buildSandboxDomainMap(baseMap)

const validation = validateDomainMapContent(merged, typesSource)
if (!validation.ok) {
  process.stderr.write("Sandbox domain-map validation failed:\n\n")
  for (const e of validation.errors) {
    process.stderr.write(`${e}\n`)
  }
  process.exit(1)
}

mkdirSync(dirname(runtimeMapPath), { recursive: true })
writeFileSync(runtimeMapPath, `${JSON.stringify(merged, null, 2)}\n`, "utf8")

const sandboxPlan = {
  version: 1 as const,
  meta: {
    generatedAt: new Date().toISOString(),
    generator: "codegen:sandbox",
  },
  entries: [
    {
      domainId: SANDBOX_DOMAIN_ID,
      table: SANDBOX_TABLE,
      read: { kind: "table" as const, name: SANDBOX_TABLE },
      methods: ["findById", "list"],
      dto: { style: "zod" as const, include: "all_columns" as const },
    },
  ],
}
writeFileSync(runtimePlanPath, `${JSON.stringify(sandboxPlan, null, 2)}\n`, "utf8")

const gen = runBackendCodegen({
  checkOnly: false,
  domainMapPath: runtimeMapPath,
  repoRoot,
  typesPath,
  planPath: runtimePlanPath,
})

if (!gen.ok) {
  for (const e of gen.errors) {
    process.stderr.write(`${e}\n`)
  }
  process.exit(1)
}

if (gen.filesWritten.length === 0) {
  process.stdout.write(
    `codegen:sandbox: nothing new (files already exist under modules/${SANDBOX_DOMAIN_ID}/). ` +
      `Run pnpm codegen:sandbox:clean then pnpm codegen:sandbox to regenerate.\n`
  )
} else {
  process.stdout.write(`Wrote ${gen.filesWritten.length} file(s):\n`)
  for (const f of gen.filesWritten) {
    process.stdout.write(`  ${f}\n`)
  }
}

process.stdout.write(
  `\nRemove sandbox output: pnpm codegen:sandbox:clean\n` +
    "(Do not commit modules/codegen-sandbox unless you intend to keep it.)\n"
)
