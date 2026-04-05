# Codegen workspace (local only)

Optional **snapshots** of generated types for a stable input when inferring
`domain-map` or running validate against a frozen file. Contents are
**gitignored**; only this README (and `.gitignore`) are tracked.

## Canonical paths (committed)

| Artefact                 | Path                                                  |
| ------------------------ | ----------------------------------------------------- |
| Generated Supabase types | `packages/supabase-infra/src/types/database.types.ts` |
| Domain map               | `config/domain-map.json`                              |

CLI defaults (`pnpm codegen:domain-map:*`, `pnpm codegen:backend`) use those
two.

## Snapshot (optional)

Copy the current generated types into this folder (ignored by git):

```bash
pnpm codegen:snapshot-types
```

Default output: `database.types.snapshot.ts` in **this** directory.

Then point validate/sync/codegen at the snapshot if you want a fixed input for
the session:

```bash
pnpm codegen:domain-map:validate -- \
  --types packages/codegen-tools/workspace/database.types.snapshot.ts \
  --map config/domain-map.json
```

**Do not** replace the canonical `database.types.ts` with a hand-edited
snapshot. Regenerate types with `pnpm supabase:types:local` or
`pnpm supabase:types:linked`.

## Tests

Unit tests use the small hand-written mock at
[`../fixtures/database.types.mock.ts`](../fixtures/database.types.mock.ts), not
this workspace.
