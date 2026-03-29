import { config } from "@workspace/eslint-config/base"

/** @type {import("eslint").Linter.Config} */
export default [
  ...config,
  {
    files: ["src/client.ts", "src/edge.ts", "src/server.ts"],
    rules: {
      "no-console": "off",
    },
  },
]
