import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { createDbProject } from "@workspace/vitest-config/db"
import { defineConfig, mergeConfig } from "vitest/config"

const testsDir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(testsDir, "..")
const supabaseInfraSrc = resolve(repoRoot, "packages/supabase-infra/src")

export default defineConfig({
  test: {
    projects: [
      mergeConfig(
        createDbProject({
          include: ["tests/rls/supabase-infra/**/*.rls.test.ts"],
          name: "supabase-infra-rls",
          root: repoRoot,
        }),
        {
          resolve: {
            alias: {
              "@workspace/supabase-infra": supabaseInfraSrc,
            },
          },
        }
      ),
    ],
  },
})
