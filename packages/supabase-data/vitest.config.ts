import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { mergeConfig } from "vitest/config"

import { createNodeProject } from "@workspace/vitest-config/node"

const dir = dirname(fileURLToPath(import.meta.url))
const srcRoot = resolve(dir, "src")
const repoRoot = resolve(dir, "../..")
const supabaseAuthSrc = resolve(dir, "../supabase-auth/src")
const supabaseInfraSrc = resolve(dir, "../supabase-infra/src")
const loggingSrc = resolve(dir, "../logging/src")

export default mergeConfig(
  createNodeProject({
    coverageInclude: [
      "src/actions/_shared/require-admin-role.ts",
      "src/actions/profiles/get-profile-by-user-id.ts",
      "src/actions/user-access/sync-user-access.ts",
      "src/actions/user-roles/get-user-roles-by-user-id.ts",
      "src/actions/user-roles/sync-user-roles.ts",
      "src/lib/supabase-repository-error.ts",
      "src/modules/profiles/**/*.ts",
      "src/modules/user-access/**/*.ts",
      "src/modules/user-roles/**/*.ts",
    ],
    include: ["../../tests/unit/supabase-data/**/*.test.ts"],
    name: "supabase-unit",
    root: ".",
  }),
  {
    resolve: {
      alias: {
        "@workspace/supabase-data": srcRoot,
        "@workspace/supabase-auth": supabaseAuthSrc,
        "@workspace/supabase-infra": supabaseInfraSrc,
        "@workspace/logging": loggingSrc,
      },
    },
    server: {
      fs: {
        allow: [repoRoot],
      },
    },
    test: {
      server: {
        deps: {
          inline: [
            /@workspace\/supabase-infra/,
            /@workspace\/logging/,
            /@workspace\/supabase-auth/,
          ],
        },
      },
    },
  }
)
