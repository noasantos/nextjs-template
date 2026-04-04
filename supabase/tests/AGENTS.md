# Supabase database tests (agents)

This folder holds **pgTAP** SQL tests that run against the **local** database
via the Supabase CLI (`pg_prove` in Docker). They assert schema, RLS, functions,
and invariants that are awkward to fake in TypeScript.

---

## Layout

| Path                           | Role                                                                               |
| ------------------------------ | ---------------------------------------------------------------------------------- |
| `pgtap/*.sql`                  | Executed by `pnpm test:db` (root script → `pnpm exec supabase test db`).           |
| `pgtap/examples/*.sql.example` | **Not executed** — copy patterns from here; extension is intentionally not `.sql`. |

Tests are run in **lexical file name order**. Older files use numeric prefixes
(`000_`, `001_`, …) for stable ordering. **New files** should use a UTC
timestamp prefix so nobody has to guess the next number.

---

## Creating a new pgTAP file (recommended)

From the **repository root**:

```bash
pnpm supabase:pgtap:new -- descriptive_snake_case_name
```

This writes
`supabase/tests/pgtap/YYYYMMDDHHMMSS_descriptive_snake_case_name.sql` with:

- `test-created-via` / `created-at-utc` header comments (same idea as stamped
  migrations),
- a minimal `begin` → `plan(1)` → `finish` → `rollback` skeleton.

**Stdout** is a single repo-relative path (easy to paste into docs or follow-up
commands).

Multiple words are joined with underscores, for example:

```bash
pnpm supabase:pgtap:new -- access control helpers
# → …_access_control_helpers.sql
```

### Why not `supabase test new`?

The official `supabase test new <name>` creates files under `supabase/tests/`
with a `_test.sql` suffix and **does not** match this repo’s convention of
keeping suites in `pgtap/` nor the timestamp prefix we use for ordering. Prefer
`pnpm supabase:pgtap:new` here.

---

## pgTAP basics (minimum)

1. Wrap the file in a transaction: `begin;` … `rollback;` (each file runs in its
   own transaction when tested, but explicit rollback matches existing suites).
2. Declare how many assertions: `select plan(n);`
3. Use pgTAP functions such as `ok()`, `is()`, `results_eq()`, `throws_ok()`,
   `has_table()`, etc.
4. End with `select * from finish();`

**Live examples in this repo:** `pgtap/000_smoke.sql` (smallest),
`pgtap/001_access_control.sql` (JWT + RPC checks).

**Annotated reference:** `pgtap/examples/minimal_pgtap.sql.example` (not run by
the CLI).

Official guide:
[Testing your database](https://supabase.com/docs/guides/database/testing) ·
[pgTAP](https://pgtap.org/).

---

## Running tests

Requires **Docker** and local Supabase (migrations applied, DB in sync):

```bash
pnpm supabase:start
pnpm supabase:db:reset   # or your usual migrate + seed flow
pnpm test:db             # root: pgTAP (`supabase test db`)
pnpm test:db:all         # integration + RLS + pgTAP (same as test:sql then test:db)
```

Vitest integration + RLS: `pnpm test:sql` (`test:integration` + `test:rls`).
Full picture: root **`AGENTS.md`** and **`docs/architecture/testing.md`**.

---

## When to add or change pgTAP

If you change **migrations**, **RLS**, **security definer functions**, or **RPC
contracts**, follow the **migration test delta** in
**`docs/architecture/database.md`**: extend pgTAP and/or RLS Vitest suites in
the **same change** as the migration, then verify with `pnpm test:db` (pgTAP),
`pnpm test:sql`, and/or `pnpm test:rls` as appropriate.

---

## Rules of thumb

- Prefer **fixed UUIDs** and **`set local role authenticated`** +
  **`set_config('request.jwt.claims', …)`** when simulating JWT-backed policies
  (see `001_access_control.sql`).
- Use **`on conflict do nothing`** (or similar) for fixture inserts into
  `auth.users` so re-runs stay idempotent.
- Do not commit secrets; tests target **local** stacks only.
- Keep one **coherent scenario per file**; split large suites rather than one
  huge `plan(50)`.

---

## Canonical repo pointers

- Migrations (CLI only): root **`AGENTS.md`**,
  **`docs/guides/migration-workflow.md`**
- Test commands: **`docs/reference/command-reference.md`**
- Process / TDD order: **`docs/architecture/tdd.md`**
