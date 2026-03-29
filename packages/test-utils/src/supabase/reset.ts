import { execFileSync } from "node:child_process"

import { repoRoot } from "@workspace/test-utils/supabase/env"

async function resetLocalSupabaseDb() {
  execFileSync("pnpm", ["supabase", "db", "reset"], {
    cwd: repoRoot,
    stdio: "inherit",
  })
}

export { resetLocalSupabaseDb }
