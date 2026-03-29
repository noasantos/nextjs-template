#!/usr/bin/env node
/**
 * Runs the same integration suite as `pnpm test:integration`, then always runs
 * `pnpm supabase:db:reset` so the local DB matches migrations + seed only.
 * Exits with the integration test exit code (reset runs even when tests fail).
 */
import { spawnSync } from "node:child_process"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")

const integration = spawnSync(
  "pnpm",
  ["exec", "dotenv", "-e", ".env.test", "--", "turbo", "test:integration"],
  { cwd: root, stdio: "inherit" },
)

spawnSync("pnpm", ["supabase:db:reset"], { cwd: root, stdio: "inherit" })

const code = integration.status
process.exit(code === 0 ? 0 : code ?? 1)
