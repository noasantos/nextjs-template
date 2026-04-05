#!/usr/bin/env tsx
/**
 * Copies database.types.ts into packages/codegen-tools/workspace/ (gitignored)
 * for a stable codegen session input. Does not replace the canonical types file.
 *
 * Usage:
 *   pnpm codegen:snapshot-types
 *   pnpm codegen:snapshot-types -- --from path/to/database.types.ts --to path/to/out.ts
 */
import { copyFileSync, mkdirSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")

function argValue(flag: string): string | undefined {
  const i = process.argv.indexOf(flag)
  if (i === -1 || !process.argv[i + 1]) {
    return undefined
  }
  return process.argv[i + 1]
}

const defaultFrom = resolve(repoRoot, "packages/supabase-infra/src/types/database.types.ts")
const defaultTo = resolve(repoRoot, "packages/codegen-tools/workspace/database.types.snapshot.ts")

const fromPath = argValue("--from") ?? defaultFrom
const toPath = argValue("--to") ?? defaultTo

mkdirSync(dirname(toPath), { recursive: true })
copyFileSync(fromPath, toPath)

process.stdout.write(
  `Copied types snapshot:\n  ${fromPath}\n  → ${toPath}\n\n` +
    "Domain map stays at config/domain-map.json (commit that file).\n"
)
