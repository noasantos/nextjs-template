#!/usr/bin/env tsx
/**
 * Deletes packages/supabase-data/src/modules/codegen-sandbox/ (pnpm codegen:sandbox output).
 */
import { existsSync, rmSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")
const sandboxModuleRoot = join(repoRoot, "packages/supabase-data/src/modules/codegen-sandbox")

if (!existsSync(sandboxModuleRoot)) {
  process.stdout.write("codegen:sandbox:clean — nothing to remove (folder missing).\n")
  process.exit(0)
}

rmSync(sandboxModuleRoot, { recursive: true, force: true })
process.stdout.write(`Removed ${sandboxModuleRoot}\n`)

const runtimeMap = join(
  repoRoot,
  "packages/codegen-tools/workspace/domain-map.sandbox-runtime.json"
)
if (existsSync(runtimeMap)) {
  rmSync(runtimeMap, { force: true })
  process.stdout.write(`Removed ${runtimeMap}\n`)
}
