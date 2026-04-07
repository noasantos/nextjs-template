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

- **`config/domain-map.example.json`** — **committed** minimal map (generic
  `demo_*` tables) aligned with
  [`database.types.mock.ts`](../../packages/codegen-tools/fixtures/database.types.mock.ts).
  Copy to `config/domain-map.json` for your project (see
  [`config/README.md`](../../config/README.md)).
- **`config/domain-map.json`** — **local** canonical map (gitignored by
  default). CLIs default to this path when present; otherwise they use
  **`domain-map.example.json`** (same pattern for **`repository-plan.json`** →
  **`repository-plan.example.json`**).
- **`config/repository-plan.example.json`** — **committed** minimal strict plan
  matching the example domain map. Copy to `config/repository-plan.json` when
  using plan-driven codegen.
- **`packages/supabase-infra/src/types/database.types.ts`** — canonical
  generated types (CLI only; never hand-edit).
- **`packages/codegen-tools/workspace/`** — optional **local** snapshots
  (gitignored). Use when you want a frozen copy of types for one session; see
  [`workspace/README.md`](../../packages/codegen-tools/workspace/README.md) and
  `pnpm codegen:snapshot-types`.
- **`packages/codegen-tools/fixtures/database.types.mock.ts`** — tiny mock
  `Database` for tests and for **`pnpm codegen:*:example`** scripts (CI uses
  these against the `*.example.json` files).

## Files (quick reference)

| File                                                                                                                     | Role                                                  |
| ------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| [`config/README.md`](../../config/README.md)                                                                             | Copy workflow: example → local `domain-map` / plan    |
| [`config/domain-map.example.json`](../../config/domain-map.example.json)                                                 | Committed generic pattern (demo domain)               |
| `config/domain-map.json` (local; copy from example — gitignored)                                                         | Your project’s map; maps tables → domains             |
| [`config/repository-plan.example.json`](../../config/repository-plan.example.json)                                       | Committed strict plan template for mock schema        |
| `config/repository-plan.json` (local; copy from example — gitignored)                                                    | Your strict repository plan                           |
| [`packages/codegen-tools/workspace/`](../../packages/codegen-tools/workspace/)                                           | Optional snapshot dir (`pnpm codegen:snapshot-types`) |
| [`packages/codegen-tools/fixtures/database.types.mock.ts`](../../packages/codegen-tools/fixtures/database.types.mock.ts) | Mock `Database` for Vitest + example validation       |

## Commands

```bash
# Template / CI: validate committed examples against the mock Database (no local DB)
pnpm codegen:domain-map:validate:example
pnpm codegen:repository-plan:validate:example
pnpm codegen:backend:check:example

# Your project: after copying example → domain-map.json + repository-plan.json and generating types
pnpm codegen:domain-map:validate

# Optional paths
pnpm codegen:domain-map:validate -- --types path/to/database.types.ts --map config/domain-map.json

# Diff report: tables missing from map vs tables removed from types
pnpm codegen:domain-map:sync

# Optional: copy canonical types into workspace/ for a stable --types path (gitignored)
pnpm codegen:snapshot-types

# Backend codegen (after domain-map + repository-plan validate)
pnpm codegen:backend --check    # default when --write omitted
pnpm codegen:backend --write    # emits DTO / mapper / port / repository / skipped integration test per plan

# Repository plan (Zod-validated JSON; method lists come from the plan)
# **Autonomous:** skill `skills/repository-plan-autonomous-pipeline/SKILL.md` — context → plan JSON → validate → `--write --force`.
pnpm codegen:repository-plan:context              # JSON input for the coding agent (deterministic)
pnpm codegen:repository-plan:context -- --sync-hint   # include domain-map vs types diff text
# Agent writes config/repository-plan.json using prompts/repository-plan/v1.md, then:
pnpm codegen:repository-plan:validate
pnpm codegen:repository-plan:validate -- --strict   # every codegen table must have a plan entry

# Plan-driven backend emit (`--plan` defaults to local plan or `*.example.json`; see `config/README.md`)
pnpm codegen:backend --check --plan config/repository-plan.json
pnpm codegen:backend --write --plan config/repository-plan.json --force
```

Every `codegen: true` table must appear in the repository plan (strict merge).
The emitter produces **only** `@workspace/supabase-data/...` imports (no `../`
under `packages/supabase-data`), optional `// @type-escape` where needed, and
mapper imports in repositories that match declared methods (no unused
`to*Insert` / `to*Update`).

Tables listed in the plan get **DTO + mapper + port + repository + skipped
integration scaffold** under `packages/supabase-data/src/modules/<domain>/`
(files include `// codegen:backend —` and use a **`.codegen` filename segment**
— e.g. `{table}.dto.codegen.ts`, `{table}-supabase.repository.codegen.ts` — so
`pnpm codegen:clean` can remove them). **Path helpers** live in
[`packages/codegen-tools/src/backend-codegen/plan-module-paths.ts`](../../packages/codegen-tools/src/backend-codegen/plan-module-paths.ts)
(import specifiers + basenames; also exported as
`@workspace/codegen-tools/backend-codegen/plan-module-paths` and from
`@workspace/codegen-tools/backend-codegen`). The matching **skipped**
integration test is emitted under
`tests/integration/supabase-data/modules/<domain>/` (same folder names as
`src/modules/<domain>/`, one `*.repository.codegen.integration.test.ts` per
table). Use `--force` to replace an existing managed file.

If `--check` says **every domain has `codegen: false`**, the tool does **no**
work: enable **`codegen: true`** on a domain (or use a workspace map for
experiments). The template keeps **`codegen: false`** only on **`profiles`** and
**`user-roles`** (hand-written repositories); other domains ship with stubs from
**`pnpm codegen:backend --write`**. **`--check` never writes files** — only
**`--write`** does.

### Try codegen end-to-end (throwaway)

`pnpm codegen:sandbox` merges `config/domain-map.json` in memory, assigns
`observability_events` to domain **`codegen-sandbox`** with **`codegen: true`**,
writes a temporary repository plan under `packages/codegen-tools/workspace/`,
and emits plan-driven files under
`packages/supabase-data/src/modules/codegen-sandbox/`. Your committed
`config/domain-map.json` is **not** modified (`observability_events` stays in
`ignoreTables` there).

```bash
pnpm codegen:sandbox
pnpm codegen:sandbox:clean   # removes that module + runtime map under workspace/
```

Run **`clean` before commits** if you only wanted to smoke-test the generator.

After **`pnpm codegen:backend --write`** on domains you keep, add explicit
`exports` in
[`packages/supabase-data/package.json`](../../packages/supabase-data/package.json).
Sandbox output is meant to be deleted with **`codegen:sandbox:clean`** (no
exports needed).

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
6. `pnpm codegen:repository-plan:validate` (if `config/repository-plan.json`
   exists).
7. `pnpm codegen:backend --check` (add `--plan config/repository-plan.json` when
   using a plan).
8. `pnpm codegen:backend --write` if you want new or updated generated files.

## Tests

- Validator / merge / emission tests:
  [`tests/unit/codegen/domain-map-validator.test.ts`](../../tests/unit/codegen/domain-map-validator.test.ts),
  [`tests/unit/codegen/repository-plan-schema.test.ts`](../../tests/unit/codegen/repository-plan-schema.test.ts),
  [`tests/unit/codegen/repository-plan-merge.test.ts`](../../tests/unit/codegen/repository-plan-merge.test.ts),
  [`tests/unit/codegen/backend-codegen-emission.test.ts`](../../tests/unit/codegen/backend-codegen-emission.test.ts)
- Run: `pnpm --filter @workspace/codegen-tools test`

## Related

- [Backend architecture](../architecture/backend.md)
- [Repository standards](../standards/repository-standards.md)
