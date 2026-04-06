#!/usr/bin/env node
/**
 * One-shot: replace parent-relative imports under packages/supabase-data/src/modules
 * with @workspace/supabase-data/modules/<domainId>/... (pnpm check:workspace-imports).
 */
import { readFileSync, readdirSync, statSync, writeFileSync } from "node:fs"
import { dirname, join, relative } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")

function walkSync(dir, out = []) {
  let names
  try {
    names = readdirSync(dir)
  } catch {
    return out
  }
  for (const name of names) {
    if (name === "node_modules") continue
    const p = join(dir, name)
    try {
      const st = statSync(p)
      if (st.isDirectory()) walkSync(p, out)
      else if (name.endsWith(".ts") && !name.endsWith(".d.ts")) out.push(p)
    } catch {
      continue
    }
  }
  return out
}

const modulesRoot = join(root, "packages", "supabase-data", "src", "modules")
const files = walkSync(modulesRoot)

let changed = 0
for (const abs of files) {
  const rel = relative(root, abs).replace(/\\/g, "/")
  const m = rel.match(/modules\/([^/]+)\//)
  if (!m) continue
  const domainId = m[1]
  const base = `@workspace/supabase-data/modules/${domainId}`
  let text = readFileSync(abs, "utf8")
  const orig = text
  text = text.replaceAll(`from "../../domain/dto/`, `from "${base}/domain/dto/`)
  text = text.replaceAll(`from "../../domain/ports/`, `from "${base}/domain/ports/`)
  text = text.replaceAll(`from "../mappers/`, `from "${base}/infrastructure/mappers/`)
  text = text.replaceAll(`from "../dto/`, `from "${base}/domain/dto/`)
  if (text !== orig) {
    writeFileSync(abs, text, "utf8")
    changed++
  }
}

console.log(`rewrite-supabase-data-workspace-imports: updated ${changed} file(s).`)
