import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import tsconfigPaths from "vite-tsconfig-paths"
import { defineConfig } from "vitest/config"

const setupDbPath = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../../test-utils/src/vitest/setup-db.ts"
)

type DbProjectOptions = {
  include: string[]
  name: string
  root: string
}

function createDbProject({ include, name, root }: DbProjectOptions) {
  return defineConfig({
    plugins: [tsconfigPaths()],
    resolve: {
      alias: {
        "server-only": fileURLToPath(new URL("./server-only-stub.js", import.meta.url)),
      },
    },
    test: {
      clearMocks: true,
      environment: "node",
      fileParallelism: false,
      globals: true,
      hookTimeout: 30_000,
      include,
      maxWorkers: 1,
      mockReset: true,
      name,
      passWithNoTests: true,
      restoreMocks: true,
      root,
      setupFiles: [setupDbPath],
      testTimeout: 15_000,
    },
  })
}

export { createDbProject, type DbProjectOptions }
