/**
 * CI guard: obvious secret-exposure patterns and unsafe public env naming.
 * Run: pnpm check:security-smells
 */
import { readFileSync, readdirSync, statSync } from "node:fs"
import { dirname, join, relative } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")

/** @param {string} dir */
function existsDir(dir) {
  try {
    return statSync(dir).isDirectory()
  } catch {
    return false
  }
}

/** @param {string} dir */
function walkTsFiles(dir, out = []) {
  let names
  try {
    names = readdirSync(dir)
  } catch {
    return out
  }
  for (const name of names) {
    if (name === "node_modules" || name === ".next" || name === "dist" || name === "coverage") {
      continue
    }
    const p = join(dir, name)
    const st = statSync(p)
    if (st.isDirectory()) {
      walkTsFiles(p, out)
    } else if (/\.(ts|tsx|mts|cts)$/.test(name)) {
      out.push(p)
    }
  }
  return out
}

/** @param {string} p */
function normalizePathPosix(p) {
  return p.replace(/\\/g, "/")
}

/** @param {string} rel */
function isTestFile(rel) {
  return (
    /\.(test|spec)\.(ts|tsx)$/.test(rel) ||
    /\.integration\.(test|spec)\.ts$/.test(rel) ||
    /\.rls\.test\.ts$/.test(rel)
  )
}

const errors = []

// Dangerous NEXT_PUBLIC_* names (never expose secrets or service role to the browser)
const unsafeNextPublicName = /\bNEXT_PUBLIC_[A-Z0-9_]*(SECRET|SERVICE_ROLE|PRIVATE_KEY)\b/g

for (const scope of ["apps", "packages"]) {
  const scopeRoot = join(root, scope)
  if (!existsDir(scopeRoot)) continue

  for (const file of walkTsFiles(scopeRoot)) {
    const rel = normalizePathPosix(relative(root, file))
    if (isTestFile(rel)) continue

    const text = readFileSync(file, "utf8")
    const badNames = text.match(unsafeNextPublicName)
    if (badNames?.length) {
      const unique = [...new Set(badNames)]
      errors.push(
        `Unsafe NEXT_PUBLIC_ env name(s) in ${rel}: ${unique.join(", ")}\n  Browser-exposed vars must not encode secrets, service role, or private keys.`,
      )
    }

    if (/^["']use client["']/m.test(text) && /\bSUPABASE_SERVICE_ROLE_KEY\b/.test(text)) {
      errors.push(
        `SUPABASE_SERVICE_ROLE_KEY referenced in a client module: ${rel}\n  Service role belongs in server-only secret stores, never in client bundles.`,
      )
    }
  }
}

// Tracked env template must not ship a literal service-role assignment
const envExample = join(root, ".env.example")
try {
  const envText = readFileSync(envExample, "utf8")
  for (const line of envText.split("\n")) {
    const trimmed = line.trim()
    if (trimmed.startsWith("#") || !trimmed) continue
    if (/^SUPABASE_SERVICE_ROLE_KEY=.+/.test(trimmed)) {
      errors.push(
        `.env.example must not set SUPABASE_SERVICE_ROLE_KEY to a value (comment-only). Found: ${trimmed.slice(0, 60)}…`,
      )
    }
  }
} catch {
  // optional file
}

if (errors.length) {
  console.error("check-security-smells failed:\n", errors.join("\n"))
  process.exit(1)
}

console.log("check-security-smells: OK")
