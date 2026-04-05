# Codegen fixtures

- **`database.types.mock.ts`** — hand-written subset of the Supabase CLI output
  (`public.Tables`, enums, FKs). Used by unit tests under `tests/unit/codegen/`.

There is **no** checked-in `domain-map.json` here: tests build a minimal valid
map from the tables declared in the mock (see `domain-map-validator.test.ts`).
The **product** domain map lives at **`config/domain-map.json`**. For optional
local copies of real types, use **`../workspace/`** and
`pnpm codegen:snapshot-types`.

Regenerate real types with `pnpm supabase:types:local` or
`pnpm supabase:types:linked`; do not replace the canonical
`packages/supabase-infra/src/types/database.types.ts` with this file.
