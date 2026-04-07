#!/usr/bin/env tsx
/**
 * Roll back workspace changes from a failed `codegen:full-pipeline` run.
 *
 * Policy: never patch `*.codegen.*` by hand — fix `scripts/codegen/*` /
 * `packages/codegen-tools/` and re-run generators.
 *
 * Order:
 * 1. `pnpm codegen:clean` — only `*.codegen.*` artifacts + semantic plan reset;
 *    `profiles` / `user-access` / `user-roles` modules are never matched.
 * 2. `git restore --source=HEAD --staged --worktree` — resets tracked trees to HEAD.
 * 3. `git clean -fd` — removes **untracked** files/dirs under the same trees
 *    (new generated modules/actions without commit, etc.).
 *
 * **Caveat:** Untracked manual files under those trees are removed. Commit or
 * stash before running the full pipeline if you rely on local-only files there.
 *
 * Used by `scripts/codegen/full-pipeline.ts` when a required step fails.
 */

import { execFileSync } from "node:child_process"
import { resolve } from "node:path"

const RESTORE_PATHSPECS = [
  "config/domain-map.json",
  "config/repository-plan.json",
  "config/action-semantic-plan.json",
  "packages/supabase-data/src/modules",
  "packages/supabase-data/src/hooks",
  "packages/supabase-data/src/actions",
  "tests/integration/supabase-data",
  "tests/unit/supabase-data",
] as const

const CLEAN_PATHSPECS = [
  "packages/supabase-data/src/modules",
  "packages/supabase-data/src/hooks",
  "packages/supabase-data/src/actions",
  "tests/integration/supabase-data",
  "tests/unit/supabase-data",
] as const

function isGitRepo(cwd: string): boolean {
  try {
    execFileSync("git", ["rev-parse", "--is-inside-work-tree"], {
      cwd,
      stdio: "pipe",
    })
    return true
  } catch {
    return false
  }
}

/**
 * Best-effort rollback; logs warnings but does not throw (caller already failed).
 */
export function rollbackCodegenWorkspace(repoRoot: string): void {
  console.log("\n⏪ Transaction rollback — reverting codegen outputs from this run...\n")

  try {
    execFileSync("pnpm", ["codegen:clean"], {
      cwd: repoRoot,
      stdio: "inherit",
    })
  } catch {
    console.error("⚠️  pnpm codegen:clean failed during rollback (continuing).\n")
  }

  if (!isGitRepo(repoRoot)) {
    console.error(
      "⚠️  Not a git checkout — only codegen:clean ran. Restore config/modules from backup or `git` manually.\n"
    )
    return
  }

  try {
    execFileSync(
      "git",
      ["restore", "--source=HEAD", "--staged", "--worktree", "--", ...RESTORE_PATHSPECS],
      { cwd: repoRoot, stdio: "inherit" }
    )
  } catch {
    console.error(
      "⚠️  git restore failed (missing paths, merge state, or no tracked files). Check status manually.\n"
    )
  }

  try {
    execFileSync("git", ["clean", "-fd", "--", ...CLEAN_PATHSPECS], {
      cwd: repoRoot,
      stdio: "inherit",
    })
  } catch {
    console.error("⚠️  git clean failed during rollback.\n")
  }

  console.log(
    "\n✅ Rollback finished (trees match last commit for tracked files; untracked under codegen dirs removed).\n"
  )
}

// Allow: pnpm tsx scripts/codegen/pipeline-rollback.ts
if (import.meta.url === `file://${process.argv[1]}`) {
  rollbackCodegenWorkspace(resolve(process.cwd()))
}
