---
name: backend-domain-codegen-init
description: >-
  Start backend codegen from a user-provided database.types.ts path: spawn a
  subagent with backend-domain-map, then run codegen:domain-map:validate and
  codegen:backend. Use when bootstrapping or refreshing supabase-data from
  schema.
---

# Backend domain codegen (init orchestrator)

## Purpose

Orchestrate **domain map → validation → stub generation** without editing
generated `database.types.ts`.

## When to trigger

- User says they want to **generate** or **refresh** `@workspace/supabase-data`
  from schema types.
- User provides a path to a `database.types.ts` file (often
  `packages/supabase-infra/src/types/database.types.ts`).

## Instructions

### 1. Gather input

- Confirm the **absolute or repo-relative path** to the types file (default:
  `packages/supabase-infra/src/types/database.types.ts`).
- Remind: if it is the repo’s canonical file, **never** hand-edit it — use
  `pnpm supabase:types:local` or `pnpm supabase:types:linked`.
- **Where outputs go:** merge and save **`config/domain-map.json`** (canonical,
  committed). Optionally run `pnpm codegen:snapshot-types` first to copy types
  into `packages/codegen-tools/workspace/database.types.snapshot.ts`
  (gitignored) and pass that path to the subagent / `--types` for a frozen
  session input.

### 2. Subagent (required)

Before writing `domain-map.json` yourself in the same turn, launch a **Task /
subagent** whose prompt:

- Loads and follows the skill **`backend-domain-map`** (this repo:
  `skills/backend-domain-map/SKILL.md`).
- Passes the types file path and, if present, existing `config/domain-map.json`
  for merge.

The subagent returns an updated **`config/domain-map.json`** body (or patch).

### 3. Validate (deterministic gate)

```bash
pnpm codegen:domain-map:validate -- --types <path-to-types> --map config/domain-map.json
```

On failure: feed validator errors back to the subagent (or fix structurally) and
repeat until exit 0.

### 4. Sync report (optional context)

```bash
pnpm codegen:domain-map:sync -- --types <path-to-types>
```

### 5. Repository plan (optional semantic layer)

For **human-free, end-to-end** plan + codegen in one run, follow skill
**[`repository-plan-autonomous-pipeline`](../repository-plan-autonomous-pipeline/SKILL.md)**
(validate → context → you author JSON for **every** codegen table → strict
validate → `codegen:backend --plan --write --force`).

Manual outline (same as that skill):

1. `pnpm codegen:domain-map:validate` then
   `pnpm codegen:repository-plan:context -- --sync-hint`.
2. Read
   [`packages/codegen-tools/prompts/repository-plan/v1.md`](../../packages/codegen-tools/prompts/repository-plan/v1.md);
   write `config/repository-plan.json` **without** human approval gates.
3. `pnpm codegen:repository-plan:validate -- --strict` →
   `pnpm codegen:backend --check --plan config/repository-plan.json --mode strict`
   → `--write` with same flags + `--force`.

See [`docs/guides/backend-codegen.md`](../../docs/guides/backend-codegen.md).

### 6. Codegen

- Check-only (CI / dry run):

  ```bash
  pnpm codegen:backend --check
  ```

- Write stubs for missing repositories (tables with `codegen: true`):

  ```bash
  pnpm codegen:backend --write
  ```

After `--write`, add explicit **`exports`** in
[`packages/supabase-data/package.json`](../../packages/supabase-data/package.json)
for new modules.

### 7. Docs and changelog

If you add or change skills/docs, update [CHANGELOG.md](../../CHANGELOG.md) per
repo rules.

### 8. Experiment: mock types + map in `workspace/` (safe)

To **try the pipeline** without changing committed
[`config/domain-map.json`](../../config/domain-map.json):

1. **Types input:**
   [`packages/codegen-tools/fixtures/database.types.mock.ts`](../../packages/codegen-tools/fixtures/database.types.mock.ts)
   (`demo_widgets`, `demo_widget_events`).
2. **Subagent** (`backend-domain-map`): infer a `version: 1` map covering those
   tables (or `ignoreTables` if appropriate).
3. **Save map** to
   **`packages/codegen-tools/workspace/domain-map.generated.json`** (folder is
   gitignored — ephemeral).
4. **Validate:**

   ```bash
   pnpm codegen:domain-map:validate -- \
     --types packages/codegen-tools/fixtures/database.types.mock.ts \
     --map packages/codegen-tools/workspace/domain-map.generated.json
   ```

5. **Codegen dry-run** (recommended first):

   ```bash
   pnpm codegen:backend -- --check \
     --types packages/codegen-tools/fixtures/database.types.mock.ts \
     --map packages/codegen-tools/workspace/domain-map.generated.json
   ```

6. **`--write`** creates real files under
   `packages/supabase-data/src/modules/<domain-id>/...` — use only if the human
   wants throwaway modules or will delete them after.

**Human shortcut (Cursor):** ask the assistant to follow this skill and say
explicitly: _use the fixture mock + workspace map + validate + backend
`--check`_.

## Out of scope (this phase)

- Frontend hooks, React Query, or app routes.
- Replacing existing hand-written repositories without human confirmation.

## References

- [docs/guides/backend-codegen.md](../../docs/guides/backend-codegen.md)
