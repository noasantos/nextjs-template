import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { createNodeProject } from "@workspace/vitest-config/node"
import { mergeConfig } from "vitest/config"

const dir = dirname(fileURLToPath(import.meta.url))
const srcRoot = resolve(dir, "src")

export default mergeConfig(
  createNodeProject({
    coverageExclude: ["src/types/**"],
    include: [
      "../../tests/unit/supabase-infra/**/*.test.ts",
      // `vi.mock('@supabase/supabase-js')` must run in package `root` (same as auth SSR mocks).
      "src/clients/create-admin-client.test.ts",
    ],
    name: "supabase-infra-unit",
    root: ".",
  }),
  {
    resolve: {
      alias: {
        "@workspace/supabase-infra": srcRoot,
      },
    },
  }
)
