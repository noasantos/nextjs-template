import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { mergeConfig } from "vitest/config"

import { createNodeProject } from "@workspace/vitest-config/node"

const dir = dirname(fileURLToPath(import.meta.url))
const srcRoot = resolve(dir, "src")
const repoRoot = resolve(dir, "../..")

export default mergeConfig(
  createNodeProject({
    coverageInclude: ["src/*.ts"],
    include: ["../../tests/unit/logging/**/*.test.ts"],
    name: "logging-unit",
    root: ".",
  }),
  {
    resolve: {
      alias: {
        "@workspace/logging": srcRoot,
      },
    },
    server: {
      fs: {
        allow: [repoRoot],
      },
    },
    test: {
      coverage: {
        exclude: [
          "src/client.ts",
          "src/edge.ts",
          "src/server-error.ts",
          "src/server.ts",
          "src/testing.ts",
        ],
        thresholds: {
          branches: 64,
          functions: 90,
          lines: 76,
          statements: 76,
        },
      },
    },
  }
)
