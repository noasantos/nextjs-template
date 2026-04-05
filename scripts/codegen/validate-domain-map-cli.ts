#!/usr/bin/env tsx
/**
 * Validates config/domain-map.json against Database["public"]["Tables"] keys.
 *
 * Usage:
 *   pnpm codegen:domain-map:validate
 *   pnpm codegen:domain-map:validate -- --types path/to/database.types.ts --map path/to/domain-map.json
 */
import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { validateDomainMapContent } from "../../packages/codegen-tools/src/validate-domain-map.ts"

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
const mapRaw = JSON.parse(readFileSync(mapPath, "utf8")) as unknown

const result = validateDomainMapContent(mapRaw, typesSource)

if (!result.ok) {
  process.stderr.write("domain-map validation failed:\n\n")
  for (const e of result.errors) {
    process.stderr.write(`${e}\n`)
  }
  process.exit(1)
}

process.stdout.write(`OK: ${mapPath} matches ${typesPath}\n`)
