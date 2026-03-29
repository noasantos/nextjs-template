# `@workspace/brand` — Agent notes

## Purpose

Shared **product-level** UI for all applications: compositions, branded patterns, and cross-app components built by **importing** `@workspace/ui/components/*` and `@workspace/ui/lib/*`.

## Boundaries

| Package | Role |
|--------|------|
| `@workspace/ui` | shadcn primitives only — **read-only** source except `pnpm dlx shadcn@latest add …` |
| `@workspace/brand` | **All** hand-written shared UI that sits above those primitives |

## Rules

- **Do not** edit `packages/ui/src/**` for product features — see [packages/ui/README.md](../ui/README.md).
- **Do** add new shared UI here (or in a specific app if it is not reused).
- Follow **GR-001** (no barrel imports for consumers): expose each component via an explicit `exports` entry in `package.json`, same pattern as `@workspace/forms`.

## `src/index.ts`

Ficheiro interno para `tsc --noEmit`; a API pública são os subpaths em `package.json` → `exports` (sem barrel).

## Exports actuais

- `./components/theme-provider` → ficheiro em `src/_providers/theme-provider.tsx` (API pública mantém o subpath `components/` por compatibilidade)
