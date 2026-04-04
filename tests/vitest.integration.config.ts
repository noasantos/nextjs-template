import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { defineConfig, mergeConfig } from "vitest/config"

import { createDbProject } from "@workspace/vitest-config/db"

const testsDir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(testsDir, "..")

const supabaseDataSrc = resolve(repoRoot, "packages/supabase-data/src")
const supabaseAuthSrc = resolve(repoRoot, "packages/supabase-auth/src")
const supabaseInfraSrc = resolve(repoRoot, "packages/supabase-infra/src")

export default defineConfig({
  test: {
    projects: [
      mergeConfig(
        createDbProject({
          include: ["tests/integration/supabase-data/**/*.integration.test.ts"],
          name: "supabase-data-integration",
          root: repoRoot,
        }),
        {
          resolve: {
            alias: {
              "@workspace/supabase-data": supabaseDataSrc,
            },
          },
        }
      ),
      mergeConfig(
        createDbProject({
          include: ["tests/integration/supabase-auth/**/*.integration.test.ts"],
          name: "supabase-auth-integration",
          root: repoRoot,
        }),
        {
          resolve: {
            alias: {
              "@workspace/supabase-auth": supabaseAuthSrc,
            },
          },
        }
      ),
      mergeConfig(
        createDbProject({
          include: ["tests/integration/supabase-infra/**/*.integration.test.ts"],
          name: "supabase-infra-integration",
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
