# Backend codegen (domain map + stubs)

Map `Database["public"]["Tables"]` to bounded domains, validate
deterministically, then emit optional repository stubs in
`@workspace/supabase-data`.

## Prerequisites

- Regenerate types after schema changes:
  - Local: `pnpm supabase:types:local`
  - Linked project (human): `pnpm supabase:types:linked`
- Do **not** hand-edit
  [`packages/supabase-infra/src/types/database.types.ts`](../../packages/supabase-infra/src/types/database.types.ts).

## Where things live

- **`config/domain-map.json`** — canonical, versioned map. On init / refresh,
  agents **write here** (merge with existing). This is not optional for the
  template: validate and backend codegen default to this path.
- **`packages/supabase-infra/src/types/database.types.ts`** — canonical
  generated types (CLI only; never hand-edit).
- **`packages/codegen-tools/workspace/`** — optional **local** snapshots
  (gitignored). Use when you want a frozen copy of types for one session; see
  [`workspace/README.md`](../../packages/codegen-tools/workspace/README.md) and
  `pnpm codegen:snapshot-types`.
- **`packages/codegen-tools/fixtures/database.types.mock.ts`** — tiny mock for
  **unit tests only**; no `domain-map` JSON is committed next to it (tests build
  a minimal map in code).

## Files (quick reference)

| File                                                                                                                     | Role                                                  |
| ------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| [`config/domain-map.json`](../../config/domain-map.json)                                                                 | Maps tables → domains, `ignoreTables`, flags          |
| [`packages/codegen-tools/workspace/`](../../packages/codegen-tools/workspace/)                                           | Optional snapshot dir (`pnpm codegen:snapshot-types`) |
| [`packages/codegen-tools/fixtures/database.types.mock.ts`](../../packages/codegen-tools/fixtures/database.types.mock.ts) | Mock `Database` for Vitest only                       |

## Commands

```bash
# Structural + coverage validation (JSON schema + every public table accounted for)
pnpm codegen:domain-map:validate

# Optional paths
pnpm codegen:domain-map:validate -- --types path/to/database.types.ts --map config/domain-map.json

# Diff report: tables missing from map vs tables removed from types
pnpm codegen:domain-map:sync

# Optional: copy canonical types into workspace/ for a stable --types path (gitignored)
pnpm codegen:snapshot-types

# Stub codegen (after validate passes)
pnpm codegen:backend --check    # default when --write omitted
pnpm codegen:backend --write    # writes missing *-supabase.repository.ts + port stubs
```

After `--write`, add explicit `exports` in
[`packages/supabase-data/package.json`](../../packages/supabase-data/package.json).

## Agent skills

- [`skills/backend-domain-codegen-init`](../../skills/backend-domain-codegen-init/SKILL.md)
  — orchestrator (subagent + validate + codegen).
- [`skills/backend-domain-map`](../../skills/backend-domain-map/SKILL.md) —
  infer and self-review `domain-map.json`.

## Post-migration checklist

1. Apply migration (stamped workflow — see
   [migration-workflow](./migration-workflow.md)).
2. `pnpm supabase:types:local` (or linked).
3. `pnpm codegen:domain-map:sync` — review output.
4. Update `config/domain-map.json` (agent skill `backend-domain-map` or manual).
5. `pnpm codegen:domain-map:validate`.
6. `pnpm codegen:backend --check` then `--write` if you want new stubs.

## Tests

- Validator tests:
  [`tests/unit/codegen/domain-map-validator.test.ts`](../../tests/unit/codegen/domain-map-validator.test.ts)
- Run: `pnpm --filter @workspace/codegen-tools test`

## Related

- [Backend architecture](../architecture/backend.md)
- [Repository standards](../standards/repository-standards.md)
