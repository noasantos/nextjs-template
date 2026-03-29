#!/usr/bin/env node
/**
 * Ensures root `.env.local` exists and has non-empty values for vars required
 * to run a local production build. Skips when CI or Vercel inject env instead.
 */
import { existsSync, readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const __dirname = dirname(fileURLToPath(import.meta.url))
const root = resolve(__dirname, "..", "..")
const envPath = resolve(root, ".env.local")

if (process.env.CI === "true" || process.env.VERCEL) {
  process.exit(0)
}

if (!existsSync(envPath)) {
  console.error("env-check-local: missing .env.local — copy from .env.example")
  process.exit(1)
}

const raw = readFileSync(envPath, "utf8")
const valueByKey = new Map()
for (const line of raw.split("\n")) {
  const trimmed = line.trim()
  if (!trimmed || trimmed.startsWith("#")) continue
  const eq = trimmed.indexOf("=")
  if (eq <= 0) continue
  const key = trimmed.slice(0, eq).trim()
  let val = trimmed.slice(eq + 1).trim()
  if (
    (val.startsWith('"') && val.endsWith('"')) ||
    (val.startsWith("'") && val.endsWith("'"))
  ) {
    val = val.slice(1, -1)
  }
  valueByKey.set(key, val)
}

const required = [
  "NEXT_PUBLIC_SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
  "NEXT_PUBLIC_PORTAL_APP_URL",
  "NEXT_PUBLIC_AUTH_APP_URL",
  "NEXT_PUBLIC_BNF_APP_URL",
  "NEXT_PUBLIC_AUTH_ALLOWED_REDIRECT_ORIGINS",
]

const missing = required.filter((k) => !valueByKey.get(k)?.trim())
if (missing.length > 0) {
  console.error(
    `env-check-local: set non-empty values in .env.local for: ${missing.join(", ")}`
  )
  process.exit(1)
}

process.exit(0)
