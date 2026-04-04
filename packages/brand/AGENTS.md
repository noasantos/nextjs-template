# `@workspace/brand` — Agent notes

## Purpose

Shared **product-level** UI for all applications: compositions, branded
patterns, and cross-app components built by **importing**
`@workspace/ui/components/*` and `@workspace/ui/lib/*`.

**Monorepo scope:** [`packages/AGENTS.md`](../AGENTS.md) — which packages use
filename suffixes vs infra-only packages.

## Boundaries

| Package            | Role                                                                                                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@workspace/ui`    | shadcn primitives only — **read-only** source except `pnpm dlx shadcn@latest add …`                                                                             |
| `@workspace/brand` | Hand-written shared **product** UI above primitives (not infra — see `@workspace/core`)                                                                         |
| `@workspace/core`  | Shared **infra** for apps: root providers, theme implementation, cross-app hooks — [docs/architecture/core-package.md](../../docs/architecture/core-package.md) |

## Rules

- **Filenames** in `src/` follow
  [package suffix conventions](../../docs/standards/package-file-suffixes.md)
  (`*.provider.tsx` under `_providers/`, etc.). **`packages/ui` is never
  edited** for this — shadcn-only.
- **Do not** edit `packages/ui/src/**` for product features — see
  [packages/ui/README.md](../ui/README.md).
- **Do** add new shared UI here (or in a specific app if it is not reused).
- Follow **GR-001** (no barrel imports for consumers): expose each component via
  an explicit `exports` entry in `package.json`, same pattern as
  `@workspace/forms`.

## `src/index.ts`

Ficheiro interno para `tsc --noEmit`; a API pública são os subpaths em
`package.json` → `exports` (sem barrel).

## Exports actuais

- `./components/theme-provider` → reexport de
  `@workspace/core/components/theme-provider` (compatibilidade; preferir import
  do core em código novo)
