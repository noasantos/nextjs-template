import "server-only"

import { execFileSync } from "node:child_process"
import { fileURLToPath } from "node:url"
import path from "node:path"

let cachedFromCli: string | null | undefined

function getMonorepoRoot(): string {
  return path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "../../../.."
  )
}

function parseServiceRoleFromSupabaseStatusEnv(output: string): string | null {
  for (const line of output.split("\n")) {
    const trimmed = line.trim()
    if (!trimmed.startsWith("SERVICE_ROLE_KEY=")) {
      continue
    }
    const value = trimmed
      .slice("SERVICE_ROLE_KEY=".length)
      .replace(/^"|"$/g, "")
    return value || null
  }
  return null
}

/**
 * When `SUPABASE_SERVICE_ROLE_KEY` is unset, resolves the local stack's service role
 * JWT from `pnpm exec supabase status -o env` (dev only). Production and CI must set
 * the env var explicitly — never rely on the CLI.
 */
function resolveServiceRoleKeyWhenUnset(): string {
  const fromEnv = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim()
  if (fromEnv) {
    return fromEnv
  }

  const isProductionLike =
    process.env.NODE_ENV === "production" || Boolean(process.env.VERCEL)

  if (isProductionLike) {
    throw new Error(
      "Missing required environment variable: SUPABASE_SERVICE_ROLE_KEY (required in production; do not commit this value)"
    )
  }

  if (cachedFromCli !== undefined) {
    if (cachedFromCli === null) {
      throw new Error(
        "Could not resolve SUPABASE_SERVICE_ROLE_KEY: set it for this environment, or run `pnpm supabase start` so the CLI can expose SERVICE_ROLE_KEY"
      )
    }
    return cachedFromCli
  }

  try {
    const output = execFileSync(
      "pnpm",
      ["exec", "supabase", "status", "-o", "env"],
      {
        cwd: getMonorepoRoot(),
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      }
    )
    const parsed = parseServiceRoleFromSupabaseStatusEnv(output)
    cachedFromCli = parsed
    if (!parsed) {
      throw new Error("SERVICE_ROLE_KEY not found in supabase status output")
    }
    return parsed
  } catch {
    cachedFromCli = null
    throw new Error(
      "Missing SUPABASE_SERVICE_ROLE_KEY: start local Supabase (`pnpm supabase start`) or set the variable only in a secure, non-committed secret store for your environment"
    )
  }
}

export { resolveServiceRoleKeyWhenUnset }
