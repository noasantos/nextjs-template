import { createRequire } from "node:module"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

import { mergeConfig } from "vitest/config"

import { createReactProject } from "@workspace/vitest-config/react"

const require = createRequire(import.meta.url)
const dir = dirname(fileURLToPath(import.meta.url))
const srcRoot = resolve(dir, "src")
const repoRoot = resolve(dir, "../..")

export default mergeConfig(
  createReactProject({
    include: [
      "../../tests/unit/supabase-auth/**/*.test.ts",
      "../../tests/unit/supabase-auth/**/*.test.tsx",
      // Heavy `vi.mock` of `next/*`, `@supabase/ssr`, workspace env: must stay under this package
      // `root` so Vitest hoisting + `next/*` resolution match the module graph (see tests/README.md).
      "src/browser/create-browser-auth-client.test.ts",
      "src/proxy/update-session.test.ts",
      "src/server/create-server-auth-client.test.ts",
      "src/session/get-claims.test.ts",
    ],
    name: "auth-unit",
    root: ".",
  }),
  {
    resolve: {
      dedupe: ["next"],
      alias: {
        "@workspace/supabase-auth": srcRoot,
        "react/jsx-runtime": require.resolve("react/jsx-runtime"),
        "react/jsx-dev-runtime": require.resolve("react/jsx-dev-runtime"),
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
            "next",
            "@supabase/ssr",
            "@supabase/supabase-js",
            /@workspace\/logging/,
            /@workspace\/supabase-infra/,
          ],
        },
      },
    },
  }
)
