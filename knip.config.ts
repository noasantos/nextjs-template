import type { KnipConfig } from "knip"

export default {
  ignore: [
    "**/node_modules/**",
    "**/*.test.ts",
    "**/*.test.tsx",
    "**/*.spec.ts",
    "**/*.spec.tsx",
    "**/*.d.ts",
    ".next/**",
    "dist/**",
    "scripts/**",
  ],
  ignoreDependencies: [
    "lefthook",
    "turbo",
    "supabase",
    // Root workspace dependencies used by apps
    "@sentry/nextjs",
    "@tanstack/react-query",
    "posthog-js",
    // apps/example dependencies (used but not detected in production mode)
    "@hookform/resolvers",
    "@workspace/core",
    "@workspace/forms",
    "@workspace/supabase-infra",
    "lucide-react",
    "next-safe-action",
    "react-hook-form",
    "sharp",
    "zod",
    // Package dependencies (used but not detected)
    "server-only",
    "@testing-library/jest-dom",
    "postcss-load-config",
  ],
  ignoreExportsUsedInFile: true,
  workspaces: {
    "apps/example": {
      entry: [
        "app/**/{page,layout,route}.tsx",
        "app/**/{page,layout,route}.ts",
        "pages/**/*.{ts,tsx}",
        "proxy.ts",
        "next.config.ts",
        "vitest.config.ts",
      ],
      project: ["**/*.{ts,tsx}"],
    },
    "packages/*": {
      entry: ["src/index.ts"],
      project: ["src/**/*.{ts,tsx}"],
    },
  },
} satisfies KnipConfig
