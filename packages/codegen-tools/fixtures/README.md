# Codegen fixtures

- **`database.types.mock.ts`** — hand-written subset of the Supabase CLI output
  (`public.Tables`, enums, FKs). Used by unit tests under `tests/unit/codegen/`.

Unit tests may build a minimal map in code (see `domain-map-validator.test.ts`).
The repo also ships **`config/domain-map.example.json`** (aligned with this
mock) for template validation (`pnpm codegen:domain-map:validate:example`). Copy
it to **`config/domain-map.json`** for your project (see root
**`config/README.md`**). For optional local copies of real types, use
**`../workspace/`** and `pnpm codegen:snapshot-types`.

Regenerate real types with `pnpm supabase:types:local` or
`pnpm supabase:types:linked`; do not replace the canonical
`packages/supabase-infra/src/types/database.types.ts` with this file.
