import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import tsconfigPaths from "vite-tsconfig-paths"
import { defineConfig } from "vitest/config"

const setupDomPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../test-utils/src/vitest/setup-dom.ts"
)

export type VitestReactProjectOptions = {
  coverageExclude?: string[]
  coverageInclude?: string[]
  exclude?: string[]
  include: string[]
  name: string
  root: string
}

export function createReactProject({
  coverageExclude = [],
  coverageInclude,
  exclude = [],
  include,
  name,
  root,
}: VitestReactProjectOptions) {
  return defineConfig({
    // Next.js tsconfig uses `"jsx": "preserve"`; Vitest must still compile JSX for tests.
    esbuild: { jsx: "automatic" },
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
      environment: "jsdom",
      exclude,
      globals: true,
      include,
      mockReset: true,
      name,
      passWithNoTests: true,
      restoreMocks: true,
      root,
      setupFiles: [setupDomPath],
    },
  })
}
