# `@workspace/core`

**Audience:** agents / LLM. Canonical architecture:
`docs/architecture/core-package.md`. Package scope (suffixes vs other packages):
[`packages/AGENTS.md`](../AGENTS.md).

Shared front-end **infra** for all apps: providers (React Query, theme,
`@workspace/ui` shell), shared components, utility hooks.

## Exports (import paths)

Disk filenames use **suffixes** (`*.provider.tsx`, `*.component.tsx`,
`*.hook.ts`) — see
[`docs/standards/package-file-suffixes.md`](../../docs/standards/package-file-suffixes.md).
Public import paths stay unchanged.

| Need                 | Import                                      |
| -------------------- | ------------------------------------------- |
| App provider tree    | `@workspace/core/providers/app`             |
| React Query defaults | `@workspace/core/providers/query-client`    |
| Theme + `useTheme`   | `@workspace/core/components/theme-provider` |
| Hydration-safe mount | `@workspace/core/hooks/use-mounted`         |

## App dependency

```json
{ "dependencies": { "@workspace/core": "workspace:*" } }
```

## Next.js

`transpilePackages` must include `@workspace/core` (with `@workspace/forms`,
`@workspace/ui` as needed).

## Scripts

`pnpm --filter=@workspace/core typecheck` · `pnpm --filter=@workspace/core lint`

## `@workspace/brand`

`@workspace/brand/components/theme-provider` re-exports core — **prefer
`@workspace/core/components/theme-provider`** in new code.
