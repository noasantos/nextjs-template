import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { mergeConfig } from "vitest/config"

import { createNodeProject } from "@workspace/vitest-config/node"

const dir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(dir, "../..")
const srcRoot = resolve(dir, "src")

export default mergeConfig(
  createNodeProject({
    coverageInclude: ["src/**/*.ts"],
    include: ["../../tests/unit/codegen/**/*.test.ts"],
    name: "codegen-tools-unit",
    root: ".",
  }),
  {
    resolve: {
      alias: {
        "@workspace/codegen-tools": srcRoot,
      },
    },
    server: {
      fs: {
        allow: [repoRoot],
      },
    },
  }
)
