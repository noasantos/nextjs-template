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

### 5. Codegen

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

### 6. Docs and changelog

If you add or change skills/docs, update [CHANGELOG.md](../../CHANGELOG.md) per
repo rules.

## Out of scope (this phase)

- Frontend hooks, React Query, or app routes.
- Replacing existing hand-written repositories without human confirmation.

## References

- [docs/guides/backend-codegen.md](../../docs/guides/backend-codegen.md)
