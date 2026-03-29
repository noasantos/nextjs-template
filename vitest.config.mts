import { defineConfig } from "vitest/config"

// Multi-project entry for `vitest` at repo root; `pnpm test` is Turbo-driven per package.
export default defineConfig({
  test: {
    projects: [
      "./apps/example/vitest.config.ts",
      "./packages/supabase-infra/vitest.config.ts",
      "./packages/supabase-auth/vitest.config.ts",
      "./packages/forms/vitest.config.ts",
      "./packages/ui/vitest.config.ts",
      "./packages/supabase-data/vitest.config.ts",
      "./tests/vitest.integration.config.ts",
      "./tests/vitest.rls.config.ts",
    ],
  },
})
