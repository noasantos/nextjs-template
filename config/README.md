# Backend codegen config (domain map + repository plan)

**What ships on the template remote:** only **`domain-map.example.json`** and
**`repository-plan.example.json`**. Keep your real `config/domain-map.json` /
`config/repository-plan.json` **local** (they are in `.gitignore`). Before you
push a template PR, **unstage** them if they were added by mistake:
`git restore --staged -- config/domain-map.json config/repository-plan.json` —
that does **not** delete the files on disk.

## Files in git

| File                                    | Role                                                                                                                                                                                                             |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`domain-map.example.json`**           | Minimal, **generic** example: maps the `demo_*` tables from [`packages/codegen-tools/fixtures/database.types.mock.ts`](../packages/codegen-tools/fixtures/database.types.mock.ts). Use as a structural template. |
| **`repository-plan.example.json`**      | Matching **strict** repository plan for that same mock schema (two tables).                                                                                                                                      |
| **`action-semantic-plan.example.json`** | Empty semantic plan shape; `pnpm codegen:clean` copies this over `action-semantic-plan.json`.                                                                                                                    |
| **`action-semantic-plan.json`**         | Committed **placeholder** in the template; Phase 0 overwrites with a real plan when you run codegen.                                                                                                             |

## CLI defaults

Commands that take `--map` / `--plan` without arguments resolve **local** files
first (`config/domain-map.json`, `config/repository-plan.json`); if a local file
is missing, they fall back to the matching **`*.example.json`** so a fresh clone
can run validation against the committed template.

For **strict** checks that must match the mock `demo_*` schema only, use the
explicit `pnpm codegen:*:example` scripts (they pass mock types and example
paths).

## Local project files (ignored in this template)

Copy the examples and align them to **your** generated `Database` types:

```bash
cp config/domain-map.example.json config/domain-map.json
cp config/repository-plan.example.json config/repository-plan.json
```

Then:

1. `pnpm supabase:types:local` (or `:linked`) so
   `packages/supabase-infra/src/types/database.types.ts` reflects your schema.
2. Infer or edit **`config/domain-map.json`** so every `public` table is
   assigned to a domain or `ignoreTables` (`pnpm codegen:domain-map:validate`).
3. Author **`config/repository-plan.json`** for codegen-enabled tables (see
   `docs/guides/backend-codegen.md`, skills `backend-domain-map` /
   `repository-plan-autonomous-pipeline`).

**This repository (template):** `config/domain-map.json` and
`config/repository-plan.json` are in **`.gitignore`** so large, product-specific
maps are not pushed upstream. Only the **`*.example.json`** files are the
canonical committed reference.

**Your fork / private clone:** if you want those two files in version control,
remove the two `config/*.json` lines from `.gitignore` (see comment there) and
commit as usual.

### If they were ever committed by mistake

Stop tracking but keep files on disk (safe before opening a template PR):

```bash
git rm --cached -- config/domain-map.json config/repository-plan.json 2>/dev/null || true
```

Check whether `origin/main` already tracks them:

```bash
git fetch origin
git ls-tree -r origin/main --name-only | grep -E '^config/(domain-map|repository-plan)\.json$' || echo "not on remote"
```

## CI / template checks

The repo validates the **example** files against the **mock** types (no real DB
required):

```bash
pnpm codegen:domain-map:validate:example
pnpm codegen:repository-plan:validate:example
pnpm codegen:backend:check:example
```
