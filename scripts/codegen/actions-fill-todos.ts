#!/usr/bin/env tsx
/**
 * Backwards-compatible bridge: generate complete action files from the semantic plan.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"

import { renderActionFile } from "./actions-hooks-codegen"
import type { SemanticPlanFile } from "./actions-semantic-plan"

const repoRoot = resolve(process.cwd())

function toKebabCase(value: string): string {
  return value
    .replace(/([a-z])([A-Z])/g, "$1-$2")
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
}

function argValue(flag: string): string | undefined {
  const index = process.argv.indexOf(flag)
  if (index === -1 || !process.argv[index + 1]) {
    return undefined
  }
  return process.argv[index + 1]
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const write = process.argv.includes("--write")
  const planPath = resolve(repoRoot, argValue("--plan") ?? "config/action-semantic-plan.json")

  if (!existsSync(planPath)) {
    process.stderr.write("action-semantic-plan.json not found\n")
    process.exit(1)
  }

  const plan = JSON.parse(readFileSync(planPath, "utf8")) as SemanticPlanFile
  const actionsDir = join(repoRoot, "packages/supabase-data/src/actions")

  for (const action of plan.actions) {
    const filePath = join(
      actionsDir,
      action.domainId,
      `${toKebabCase(action.table)}-${toKebabCase(action.method)}.codegen.ts`
    )

    if (!write) {
      console.log(`Would generate ${filePath}`)
      continue
    }

    mkdirSync(dirname(filePath), { recursive: true })
    writeFileSync(filePath, renderActionFile(action), "utf8")
    console.log(`Generated ${filePath}`)
  }
}
