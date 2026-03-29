import { createRequire } from "node:module"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { createReactProject } from "@workspace/vitest-config/react"
import { mergeConfig } from "vitest/config"

const require = createRequire(import.meta.url)
const dir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(dir, "../..")

/**
 * Tests live under `tests/` (outside this package root). Do not alias bare `react` to
 * `react/index.js` — Vite treats that as a prefix and breaks `react/jsx-dev-runtime`.
 */
export default mergeConfig(
  createReactProject({
    coverageInclude: [
      "src/components/data-table.tsx",
      "src/components/field.tsx",
      "src/components/form.tsx",
      "src/components/table.tsx",
    ],
    include: [
      "../../tests/unit/ui/**/*.test.ts",
      "../../tests/unit/ui/**/*.test.tsx",
    ],
    name: "ui-unit",
    root: ".",
  }),
  {
    resolve: {
      alias: {
        // Tests live under `tests/`; tsconfig paths are rooted in this package.
        "@workspace/ui": resolve(dir, "src"),
        "react-hook-form": require.resolve("react-hook-form"),
        "react/jsx-runtime": require.resolve("react/jsx-runtime"),
        "react/jsx-dev-runtime": require.resolve("react/jsx-dev-runtime"),
      },
    },
    server: {
      fs: {
        allow: [repoRoot],
      },
    },
  }
)
