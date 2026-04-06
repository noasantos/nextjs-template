---
name: repository-plan-autonomous-pipeline
description: >-
  Human-free end-to-end: run deterministic context commands, perform semantic
  analysis as the agent to author config/repository-plan.json for every codegen
  table, validate, then pnpm codegen:backend --plan --write. Use when refreshing
  plan-driven repositories or bootstrapping repository-plan.json without human
  approval steps.
---

# Repository plan — autonomous pipeline (agent-only semantic step)

## Purpose

Run the full chain in **one agent session**, with **no human decision gates**:

1. **Deterministic data prep** — shell commands produce structured JSON +
   optional sync text.
2. **Non-deterministic semantic pass** — **you (the agent)** read that output +
   schema rules and **write** `config/repository-plan.json` (methods, read/view
   targets, DTO hints).
3. **Deterministic codegen** — Zod merge validation + `codegen:backend --plan`
   check + write.

There is no separate OpenAI product API in-repo; **your reasoning is the
semantic layer.**

## When to trigger

- User asks to **generate or refresh** `repository-plan.json` and plan-driven
  repos **without** waiting on human choices.
- User says **autonomous**, **full pipeline**, **semantics + codegen**, or
  **repository plan end-to-end**.

## Preconditions

- [`config/domain-map.json`](../../config/domain-map.json) exists and should be
  valid.
- Canonical types at
  [`packages/supabase-infra/src/types/database.types.ts`](../../packages/supabase-infra/src/types/database.types.ts)
  (or pass `--types` consistently in every command below).

## Instructions (execute in order, same turn)

### Phase 1 — Deterministic inputs (shell)

Run and **capture stdout** of the context JSON:

```bash
pnpm codegen:domain-map:validate
pnpm codegen:repository-plan:context -- --sync-hint
```

If validate fails, **you** fix `domain-map.json` (or types path) and re-run
until exit 0 — **do not** ask a human which domain a table belongs to; infer
from naming/FKs like skill `backend-domain-map`, then validate again.

Parse the JSON: `publicTables`, `publicViews`, `codegenDomains`, optional
`domainMapSyncReport`.

### Phase 2 — Semantic plan (agent only, non-deterministic)

1. Read
   [`packages/codegen-tools/prompts/repository-plan/v1.md`](../../packages/codegen-tools/prompts/repository-plan/v1.md)
   and
   [`packages/codegen-tools/src/repository-plan-schema.ts`](../../packages/codegen-tools/src/repository-plan-schema.ts)
   for allowed fields and enums.
2. Open **`database.types.ts`** as needed (grep / read sections) for Row columns
   when choosing `idColumn`, `softDelete.column`, `upsert.onConflict`, or view
   vs table reads.
3. Produce **`config/repository-plan.json`** with:
   - `version`: `1`
   - `meta.generatedAt`: current ISO-8601 UTC
   - `meta.generator`: `cursor-agent` (or your runtime id)
   - `meta.promptVersion`: `v1`
   - **`entries`**: **exactly one entry per `(domainId, table)`** appearing in
     `codegenDomains` (every table in every codegen-enabled domain). This keeps
     `--strict` validation and full coverage without human triage.

**No human in the loop:** do **not** stop to ask which methods to generate. If
ambiguous, use **defaults** below.

#### Defaults (when not obvious from product context)

| Situation                                                                                                                   | Default `methods`                                                                             |
| --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Domain `readOnly: true`                                                                                                     | `findById`, `list`                                                                            |
| Writable domain, typical entity table                                                                                       | `findById`, `list`, `insert`, `update`, `delete`                                              |
| Writable domain, name suggests append-only / ingest (`*_log`, `*_audit`, `*_events` ingest, `*_dead_letter`, `idempotency`) | `findById`, `list`, `insert` (add `update` only if types show mutable columns you will touch) |

- **`upsert`**: add only when you infer a stable natural key / `onConflict` from
  types or domain (e.g. idempotency key). Otherwise omit.
- **`softDelete`**: add only when the **write** table Row clearly has a column
  you will set (e.g. `archived_at`, `deleted_at`). Include
  `softDelete: { column: "..." }` and put `softDelete` in `methods`.
- **`read`**: `{ "kind": "table", "name": "<table>" }` unless you deliberately
  map a **view** from `publicViews`.
- **`dto`**: `{ "style": "zod", "include": "all_columns" }` unless the Row is
  enormous and a subset is clearly safe (still must pass merge validation).

Write the file to **`config/repository-plan.json`**.

### Phase 3 — Deterministic gates (shell)

```bash
pnpm codegen:repository-plan:validate -- --strict
pnpm codegen:backend --check --plan config/repository-plan.json --mode strict
pnpm codegen:backend --write --plan config/repository-plan.json --mode strict --force
```

- If validate or `--check` fails, **you** fix `repository-plan.json` (or
  domain-map) and repeat Phase 3 — still without asking a human unless the repo
  is genuinely inconsistent (e.g. types file missing).

### Phase 4 — Package surface

Add or adjust **`exports`** in
[`packages/supabase-data/package.json`](../../packages/supabase-data/package.json)
for any **new** module paths the generator created.

### Phase 5 — Sanity

Run `pnpm typecheck` (or the narrowest filter that covers
`@workspace/supabase-data` and `codegen-tools`) and fix any errors you
introduced.

## Independence

This skill is **self-contained**: you do not require skill
`backend-domain-codegen-init` to finish, though domain-map may first need skill
**`backend-domain-map`** if `domain-map:validate` fails.

## Related skills

- [`backend-domain-map`](../backend-domain-map/SKILL.md) — (re)build
  `domain-map.json` if Phase 1 fails.
- [`backend-domain-codegen-init`](../backend-domain-codegen-init/SKILL.md) —
  broader bootstrap; use this skill when plan-driven output must run
  autonomously.

## References

- [docs/guides/backend-codegen.md](../../docs/guides/backend-codegen.md)
- [docs/architecture/backend.md](../../docs/architecture/backend.md)
