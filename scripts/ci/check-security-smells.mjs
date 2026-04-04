#!/usr/bin/env node
/**
 * Security Smells Check
 *
 * Scans codebase for common security issues:
 * - NEXT_PUBLIC_*SECRET* patterns
 * - Hardcoded credentials
 * - Insecure patterns
 */

import { readdirSync, readFileSync, statSync } from "node:fs"
import { join, relative } from "node:path"

function normalizePathPosix(p) {
  return p.replace(/\\/g, "/")
}

const forbiddenPatterns = [
  {
    pattern: /NEXT_PUBLIC_.*SECRET/i,
    message: "NEXT_PUBLIC_ should not contain SECRET",
  },
  {
    pattern: /SUPABASE_SERVICE_ROLE_KEY.*NEXT_PUBLIC/i,
    message: "Service role key exposed to client",
  },
  {
    pattern: /password\s*[:=]\s*['"][^'"]+['"]/i,
    message: "Hardcoded password detected",
  },
  {
    pattern: /api[_-]?key\s*[:=]\s*['"][^'"]+['"]/i,
    message: "Hardcoded API key detected",
  },
  {
    pattern: /secret\s*[:=]\s*['"][^'"]+['"]/i,
    message: "Hardcoded secret detected",
  },
  {
    pattern: /console\.log.*password/i,
    message: "Logging sensitive data (password)",
  },
  {
    pattern: /console\.log.*token/i,
    message: "Logging sensitive data (token)",
  },
  {
    pattern: /console\.log.*secret/i,
    message: "Logging sensitive data (secret)",
  },
]

const sensitiveFiles = new Set([".env", ".env.local", ".env.test", ".env.remote"])

function shouldSkipScannedFile(filePath) {
  const rel = normalizePathPosix(relative(process.cwd(), filePath))
  if (rel.startsWith("tests/") || rel.startsWith("skills/")) return true
  if (rel.endsWith(".md")) return true
  return false
}

function checkFile(filePath) {
  if (shouldSkipScannedFile(filePath)) {
    return true
  }

  try {
    const stat = statSync(filePath)
    if (stat.isSymbolicLink()) {
      return true // Skip symlinks
    }
  } catch {
    return true // Skip files we can't read
  }

  const content = readFileSync(filePath, "utf-8")
  const fileName = filePath.split("/").pop()

  // Skip sensitive files (should be in .gitignore)
  if (sensitiveFiles.has(fileName)) {
    return true
  }

  let hasErrors = false

  for (const { pattern, message } of forbiddenPatterns) {
    if (pattern.test(content)) {
      console.error(`❌ ${filePath}: ${message}`)
      hasErrors = true
    }
  }

  return !hasErrors
}

function walkDir(dir) {
  const files = readdirSync(dir, { withFileTypes: true })
  let allValid = true

  for (const file of files) {
    const filePath = join(dir, file.name)

    if (file.isDirectory()) {
      // Skip node_modules and other ignored directories
      if (
        !file.name.startsWith(".") &&
        file.name !== "node_modules" &&
        file.name !== ".next" &&
        file.name !== "dist" &&
        file.name !== "coverage" &&
        file.name !== "tests" &&
        file.name !== "skills"
      ) {
        const valid = walkDir(filePath)
        allValid = allValid && valid
      }
    } else if (
      file.name.endsWith(".ts") ||
      file.name.endsWith(".tsx") ||
      file.name.endsWith(".js") ||
      file.name.endsWith(".jsx") ||
      file.name.endsWith(".json") ||
      file.name.endsWith(".md")
    ) {
      const valid = checkFile(filePath)
      allValid = allValid && valid
    }
  }

  return allValid
}

console.log("🔍 Scanning for security smells...")
console.log("")

const isValid = walkDir(process.cwd())

console.log("")
if (isValid) {
  console.log("✅ No security smells found")
  process.exit(0)
} else {
  console.log("❌ Security smells detected! Please fix violations.")
  process.exit(1)
}
