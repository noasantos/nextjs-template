/**
 * Enforce no parent-segment relative imports (`../`) under apps/ and packages/.
 * Use `@workspace/*` (packages) or app aliases such as `@/` (Next apps) instead.
 *
 * Run: pnpm check:workspace-imports
 * Same rule as .cursor/rules/no-relative-imports.mdc (executable gate).
 */
import { readdirSync, readFileSync, statSync } from "node:fs"
import { dirname, join, relative } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")

/** @type {RegExp[]} */
const PATTERNS = [/\bfrom\s+["'](\.\.\/[^"']+)["']/g, /\bimport\s*\(\s*["'](\.\.\/[^"']+)["']/g]

/**
 * @param {string} dir
 * @param {string[]} out
 */
function walkTsFiles(dir, out = []) {
  let names
  try {
    names = readdirSync(dir)
  } catch {
    return out
  }
  for (const name of names) {
    if (
      name === "node_modules" ||
      name === ".next" ||
      name === "dist" ||
      name === "coverage" ||
      name === ".turbo"
    ) {
      continue
    }
    const p = join(dir, name)
    try {
      const st = statSync(p)
      if (st.isSymbolicLink()) continue
      if (st.isDirectory()) walkTsFiles(p, out)
      else if (/\.(ts|tsx)$/.test(name) && !name.endsWith(".d.ts")) out.push(p)
    } catch {
      continue
    }
  }
  return out
}

/** @param {string} text */
function findViolations(text) {
  /** @type {string[]} */
  const paths = []
  for (const re of PATTERNS) {
    re.lastIndex = 0
    let m
    while ((m = re.exec(text)) !== null) {
      paths.push(m[1])
    }
  }
  return paths
}

const errors = []

for (const scope of ["apps", "packages"]) {
  const scopeRoot = join(root, scope)
  try {
    if (!statSync(scopeRoot).isDirectory()) continue
  } catch {
    continue
  }

  for (const file of walkTsFiles(scopeRoot)) {
    const rel = relative(root, file)
    const text = readFileSync(file, "utf8")
    const unique = [...new Set(findViolations(text))]
    if (unique.length) {
      errors.push(
        `${rel}\n  Parent relative import(s) not allowed: ${unique.join(", ")}\n  Use @workspace/... or @/... instead of ../ (see pnpm check:workspace-imports / .cursor/rules/no-relative-imports.mdc).`
      )
    }
  }
}

if (errors.length) {
  console.error("check-workspace-imports failed:\n\n" + errors.join("\n\n"))
  process.exit(1)
}

console.log("check-workspace-imports: OK")
