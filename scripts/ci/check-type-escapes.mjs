#!/usr/bin/env node
/**
 * Enforces that every `as never`, `as unknown as`, and `@ts-ignore` in production
 * source is annotated with a `// @type-escape:` comment on the preceding line.
 * Fails CI if any unannotated escape hatch is found.
 */
import { execSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"

const ESCAPE_PATTERNS = [/\bas never\b/, /\bas unknown as\b/, /@ts-ignore/, /@ts-expect-error/]

const ANNOTATION = /\/\/ @type-escape:/

const files = execSync(
  "git ls-files '*.ts' '*.tsx' ':!*.test.ts' ':!*.test.tsx' ':!*.spec.ts' ':!node_modules'",
  { encoding: "utf8" }
)
  .trim()
  .split("\n")
  .filter(Boolean)

let violations = 0

for (const file of files) {
  if (!existsSync(file)) {
    continue
  }
  const lines = readFileSync(file, "utf8").split("\n")
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (ESCAPE_PATTERNS.some((p) => p.test(line))) {
      const prev = lines[i - 1] ?? ""
      if (!ANNOTATION.test(prev)) {
        console.error(`MISSING @type-escape annotation: ${file}:${i + 1}`)
        console.error(`  ${line.trim()}`)
        violations++
      }
    }
  }
}

if (violations > 0) {
  console.error(
    `\n${violations} unannotated type escape(s) found. Add // @type-escape: comment above each.`
  )
  process.exit(1)
}

console.log("✓ All type escapes are annotated.")
