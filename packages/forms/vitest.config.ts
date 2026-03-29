import { createRequire } from "node:module"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { createReactProject } from "@workspace/vitest-config/react"
import { mergeConfig } from "vitest/config"

const require = createRequire(import.meta.url)
const dir = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(dir, "../..")

export default mergeConfig(
  createReactProject({
    include: [
      "../../tests/unit/forms/**/*.test.ts",
      "../../tests/unit/forms/**/*.test.tsx",
    ],
    name: "forms-unit",
    root: ".",
  }),
  {
    resolve: {
      alias: {
        "@workspace/forms": resolve(dir, "src"),
        "@workspace/ui": resolve(dir, "../ui/src"),
        zod: require.resolve("zod"),
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
