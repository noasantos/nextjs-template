# @workspace/codegen-tools

Domain-map validation (Zod + TypeScript AST), sync report, and optional backend
stub emission for `@workspace/supabase-data`.

## Commands (from repo root)

- `pnpm codegen:domain-map:validate`
- `pnpm codegen:domain-map:sync`
- `pnpm codegen:snapshot-types` (writes under `workspace/`, gitignored)
- `pnpm codegen:backend --check` / `--write`

## Docs

[Backend codegen](../../docs/guides/backend-codegen.md)
