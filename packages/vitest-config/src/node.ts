import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import tsconfigPaths from "vite-tsconfig-paths"
import { defineConfig } from "vitest/config"

/** From `packages/vitest-config/src|dist` → `packages/test-utils` (no pkg dep; avoids workspace cycle). */
const setupNodePath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../test-utils/src/vitest/setup-node.ts"
)

type NodeProjectOptions = {
  coverageExclude?: string[]
  coverageInclude?: string[]
  exclude?: string[]
  include: string[]
  name: string
  root: string
}

function createNodeProject({
  coverageExclude = [],
  coverageInclude,
  exclude = [],
  include,
  name,
  root,
}: NodeProjectOptions) {
  return defineConfig({
    plugins: [tsconfigPaths()],
    resolve: {
      alias: {
        "server-only": fileURLToPath(new URL("./server-only-stub.js", import.meta.url)),
      },
    },
    test: {
      clearMocks: true,
      coverage: {
        exclude: [
          "**/*.d.ts",
          "**/test/**",
          "**/*.config.*",
          "**/vitest.config.ts",
          ...coverageExclude,
        ],
        ...(coverageInclude && { include: coverageInclude }),
        provider: "v8",
        reporter: ["text", "html", "lcov"],
        reportsDirectory: "./coverage",
        thresholds: {
          branches: 75,
          functions: 80,
          lines: 80,
          statements: 80,
        },
      },
      environment: "node",
      exclude,
      globals: true,
      include,
      mockReset: true,
      name,
      passWithNoTests: true,
      restoreMocks: true,
      root,
      setupFiles: [setupNodePath],
    },
  })
}

export { createNodeProject, type NodeProjectOptions }
