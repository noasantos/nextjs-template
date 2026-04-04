#!/usr/bin/env node

/**
 * Pre-commit hook script that enforces changelog entries
 *
 * Checks if staged files require a CHANGELOG.md entry and verifies
 * that an "Unreleased" section exists with actual content.
 */

import { execSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"

// Configuration
const CHANGELOG_FILE = "CHANGELOG.md"
const UNRELEASED_SECTION = "## [Unreleased]"
const MAX_LINES_TO_CHECK = 30

// File patterns that NEED changelog entries
const INCLUDE_PATTERNS = [
  "^docs/",
  "^skills/",
  "^scripts/",
  "^packages/",
  "^apps/",
  "^\\.cursor/rules/",
  "^lefthook\\.yml$",
  "^turbo\\.json$",
  "^tsconfig\\.json$",
]

// File patterns that are EXEMPT from changelog
const EXEMPT_PATTERNS = [
  "\\.gitignore$",
  "\\.npmrc$",
  "^pnpm-lock\\.yaml$",
  "^CHANGELOG\\.md$",
  "^\\.env.*",
  "\\.gitattributes$",
]

// File extensions to check
const RELEVANT_EXTENSIONS = [
  ".md",
  ".mdx",
  ".ts",
  ".tsx",
  ".js",
  ".mjs",
  ".cjs",
  ".json",
  ".yml",
  ".yaml",
  ".sql",
]

/**
 * Get list of staged files from git
 * @returns {string[]} Array of file paths
 */
function getStagedFiles() {
  try {
    const output = execSync("git diff --cached --name-only", {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "ignore"],
    })
    return output
      .split("\n")
      .filter((line) => line.trim() !== "")
      .map((line) => line.trim())
  } catch (_error) {
    // Not in a git repo or no staged files
    return []
  }
}

/**
 * Check if a file path matches any of the given patterns
 * @param {string} filePath - The file path to check
 * @param {string[]} patterns - Array of regex patterns
 * @returns {boolean} True if matches any pattern
 */
function matchesPattern(filePath, patterns) {
  return patterns.some((pattern) => new RegExp(pattern).test(filePath))
}

/**
 * Check if file has a relevant extension
 * @param {string} filePath - The file path to check
 * @returns {boolean} True if has relevant extension
 */
function hasRelevantExtension(filePath) {
  return RELEVANT_EXTENSIONS.some((ext) => filePath.endsWith(ext))
}

/**
 * Determine if a file needs a changelog entry
 * @param {string} filePath - The file path to check
 * @returns {boolean} True if file needs changelog entry
 */
function isRelevantFile(filePath) {
  // Skip exempt files
  if (matchesPattern(filePath, EXEMPT_PATTERNS)) {
    return false
  }

  // Check if file is in included paths
  if (!matchesPattern(filePath, INCLUDE_PATTERNS)) {
    return false
  }

  // Check if file has relevant extension
  if (!hasRelevantExtension(filePath)) {
    return false
  }

  return true
}

/**
 * Check if CHANGELOG.md has a recent Unreleased section with content
 * @returns {boolean} True if changelog has valid Unreleased section
 */
function changelogHasRecentEntry() {
  const changelogPath = join(process.cwd(), CHANGELOG_FILE)

  if (!existsSync(changelogPath)) {
    return false
  }

  try {
    const content = readFileSync(changelogPath, "utf-8")
    const lines = content.split("\n")

    // Only check first MAX_LINES_TO_CHECK lines
    const checkLines = lines.slice(0, MAX_LINES_TO_CHECK)

    let foundUnreleased = false
    let hasContent = false

    for (const line of checkLines) {
      if (line.trim() === UNRELEASED_SECTION) {
        foundUnreleased = true
        continue
      }

      if (foundUnreleased) {
        // Check if there's actual content (not just whitespace or version headers)
        const trimmed = line.trim()
        if (trimmed === "") {
          continue
        }
        // Skip horizontal rules (markdown separators)
        if (trimmed === "---" || trimmed.startsWith("---")) {
          continue
        }
        if (trimmed.startsWith("## ")) {
          // Hit another version section (e.g., "## [1.0.0]") without content
          return false
        }
        // Found actual content (subsection headers like "### Added" count as content)
        hasContent = true
        break
      }
    }

    return foundUnreleased && hasContent
  } catch (_error) {
    return false
  }
}

/**
 * Format a helpful error message for the user
 * @param {string[]} files - Array of files needing changelog entry
 * @returns {string} Formatted error message
 */
function formatErrorMessage(files) {
  const fileCount = files.length
  const fileLabel = fileCount === 1 ? "file" : "files"

  let message = `
╔══════════════════════════════════════════════════════════════════════════════╗
║                         CHANGELOG ENTRY REQUIRED                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

${fileCount} staged ${fileLabel} require${fileCount === 1 ? "s" : ""} a CHANGELOG.md entry:

`

  // List files
  files.forEach((file, index) => {
    message += `  ${index + 1}. ${file}\n`
  })

  message += `
═══════════════════════════════════════════════════════════════════════════════
HOW TO FIX:
═══════════════════════════════════════════════════════════════════════════════

1. Open CHANGELOG.md

2. Find the "## Unreleased" section (or create it at the top)

3. Add an entry describing your changes:

   Example format:
   - [type] Description of what changed

   Type labels:
   • [feat]     - New feature or enhancement
   • [fix]      - Bug fix
   • [docs]     - Documentation changes
   • [break]    - Breaking change
   • [security] - Security-related fix
   • [perf]     - Performance improvement
   • [refactor] - Code refactoring (no behavior change)

═══════════════════════════════════════════════════════════════════════════════
EXAMPLES:
═══════════════════════════════════════════════════════════════════════════════

For docs/skills/new-feature.md:
  - [docs] Add documentation for new feature X

For packages/core/src/utils.ts:
  - [feat] Add utility function for data transformation

For .cursor/rules/new-rule.mdc:
  - [feat] Add AI rule for code style enforcement

For scripts/ci/new-script.mjs:
  - [perf] Add script to optimize CI pipeline

═══════════════════════════════════════════════════════════════════════════════

After adding your entry, commit again.
`

  return message
}

/**
 * Main function to orchestrate the changelog check
 */
function main() {
  // Get all staged files
  const allStagedFiles = getStagedFiles()

  if (allStagedFiles.length === 0) {
    // No staged files, exit successfully
    process.exit(0)
  }

  // Filter to only relevant files
  const relevantFiles = allStagedFiles.filter(isRelevantFile)

  if (relevantFiles.length === 0) {
    // No relevant files staged, exit successfully
    process.exit(0)
  }

  // Check if changelog has recent entry
  const hasChangelogEntry = changelogHasRecentEntry()

  if (hasChangelogEntry) {
    // Changelog has entry, exit successfully
    process.exit(0)
  }

  // Display error message and exit with failure
  console.error(formatErrorMessage(relevantFiles))
  process.exit(1)
}

// Run the check
main()
