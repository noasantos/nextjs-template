/**
 * Enforce 1:1 parity between .cursor/rules/*.mdc and docs/standards/rules/<same>.md
 * so contributors without Cursor get the same rule set in docs.
 *
 * Run: pnpm check:cursor-rules-parity
 */
import { readdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")
const cursorDir = join(root, ".cursor", "rules")
const docsDir = join(root, "docs", "standards", "rules")

const cursor = new Set(
  readdirSync(cursorDir)
    .filter((f) => f.endsWith(".mdc"))
    .map((f) => f.replace(/\.mdc$/, ""))
)

const docs = new Set(
  readdirSync(docsDir)
    .filter((f) => f.endsWith(".md") && f !== "README.md")
    .map((f) => f.replace(/\.md$/, ""))
)

const missingInDocs = [...cursor].filter((b) => !docs.has(b)).toSorted()
const extraInDocs = [...docs].filter((b) => !cursor.has(b)).toSorted()

if (missingInDocs.length || extraInDocs.length) {
  console.error("check-cursor-rules-parity failed.")
  console.error(
    `  .cursor/rules: ${cursor.size} rules, docs/standards/rules: ${docs.size} rule files (excl. README).`
  )
  if (missingInDocs.length) {
    console.error(`  Missing docs for: ${missingInDocs.join(", ")}`)
  }
  if (extraInDocs.length) {
    console.error(`  Extra docs (no .mdc): ${extraInDocs.join(", ")}`)
  }
  console.error(
    "\n  Fix: add/remove docs/standards/rules/<name>.md or run `node scripts/ci/sync-cursor-rules-to-docs.mjs` after updating .mdc files."
  )
  process.exit(1)
}

console.log(
  `check-cursor-rules-parity: OK (${cursor.size} rules mirrored in docs/standards/rules/)`
)
