import { nextJsConfig } from "#eslint-config/next"

/**
 * ESLint for Next.js **apps** only: bans direct @supabase/supabase-js imports (BAD-003 / BACKEND.md).
 *
 * @type {import("eslint").Linter.Config}
 */
export const nextAppConfig = [
  ...nextJsConfig,
  {
    files: ["**/*.{ts,tsx}"],
    rules: {
      "no-restricted-imports": [
        "error",
        {
          paths: [
            {
              name: "@supabase/supabase-js",
              message:
                "Apps must not import @supabase/supabase-js. Use /supabase-auth, /supabase-infra, or shared data packages per BACKEND.md.",
            },
            {
              name: "@workspace/logging/server-error",
              message:
                "Apps must use the structured observability APIs from @workspace/logging/server or @workspace/logging/client.",
            },
          ],
        },
      ],
    },
  },
]
