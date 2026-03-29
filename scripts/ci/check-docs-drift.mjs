import { readFileSync, statSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")

const rootPackageJson = JSON.parse(
  readFileSync(join(root, "package.json"), "utf8")
)

const docsToCheck = [
  "AGENTS.md",
  "docs/reference/command-reference.md",
  "docs/README.md",
  "docs/architecture/testing.md",
]

const errors = []

function ensureFileExists(relativePath) {
  try {
    statSync(join(root, relativePath))
    return true
  } catch {
    return false
  }
}

function normalizeLocalLinkTarget(target) {
  return target.split("#")[0]?.split("?")[0] ?? target
}

function extractCodeBlocks(text) {
  return [...text.matchAll(/```[\s\S]*?```/g)].map((match) => match[0] ?? "")
}

for (const relativePath of docsToCheck) {
  const text = readFileSync(join(root, relativePath), "utf8")

  for (const match of text.matchAll(/\[[^\]]+\]\((?!https?:|mailto:|#)([^)]+)\)/g)) {
    const target = normalizeLocalLinkTarget(match[1] ?? "")
    if (!target) continue
    const resolved = resolve(dirname(join(root, relativePath)), target)
    try {
      statSync(resolved)
    } catch {
      errors.push(`Broken local docs link in ${relativePath}: ${target}`)
    }
  }

  for (const block of extractCodeBlocks(text)) {
    for (const line of block.split("\n")) {
      const trimmed = line.trim()
      if (!trimmed || trimmed.startsWith("#")) continue

      for (const match of trimmed.matchAll(/\bpnpm\s+([a-z0-9][a-z0-9:_-]*)\b/gi)) {
        const command = match[1]
        if (!command) continue
        if (
        command === "exec" ||
        command === "dlx" ||
        command === "install" ||
        command === "list" ||
        command === "add" ||
        command === "update" ||
        command === "remove" ||
        command === "version" ||
        command === "completion" ||
        command === "turbo"
      ) {
        continue
      }
      if (command === "--filter" || command.startsWith("-")) continue
      if (!rootPackageJson.scripts?.[command]) {
        errors.push(
          `Documented root pnpm command is missing from package.json scripts: ${command} (seen in ${relativePath})`
        )
      }
      }
    }
  }
}

for (const requiredPath of [
  ".github/workflows/quality.yml",
  ".github/workflows/db-verification.yml",
  ".github/workflows/codeql.yml",
  ".github/workflows/dependency-review.yml",
  ".github/dependabot.yml",
  ".github/pull_request_template.md",
  "docs/architecture/decisions/ADR_TEMPLATE.md",
]) {
  if (!ensureFileExists(requiredPath)) {
    errors.push(`Expected repository hygiene artifact is missing: ${requiredPath}`)
  }
}

if (errors.length > 0) {
  console.error("check-docs-drift failed:\n", errors.join("\n"))
  process.exit(1)
}

console.log("check-docs-drift: OK")
