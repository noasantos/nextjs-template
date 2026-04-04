# Test-Driven Development (Strict)

This repository uses **RED → GREEN → REFACTOR**, adapted for **CLI-only Supabase
migrations**. This file is the **canonical process**.
[AGENTS.md](../../AGENTS.md) routes here;
[Database → Migrations](./database.md#migrations) owns migration mechanics;
[Testing](./testing.md) owns Vitest and RLS test setup.

---

## Non-Negotiables

| MUST                                                                                                                                                                                                                                            | MUST NEVER                                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Define Zod + boundary types before implementation ([GR-009](../standards/golden-rules.md#gr-009-named-async-contracts))                                                                                                                         | Create migration files without `pnpm supabase:migration:new` or paste SQL into a hand-made path ([GR-015](../standards/golden-rules.md#gr-015-cli-generated-migrations-only-critical---human-confirmation-required)) |
| Ship a **test delta** with every migration change: extend [pgTAP](../../supabase/tests/pgtap/) and/or [RLS tests](../../packages/supabase-infra/) as required by [Database — Migration test delta](./database.md#migration-test-delta-required) | Merge migrations with no new or updated tests when the change warrants coverage (schema, policies, RPCs, authz)                                                                                                      |
| Run `pnpm test:coverage` before claiming a feature is done (see [local verification](#local-verification-and-database-tests))                                                                                                                   | Add `apps/*/lib/db/**` or `apps/*/lib/repositories/**` ([BAD-003](../standards/anti-patterns.md#bad-003-app-local-data-abstractions))                                                                                |
| Use integration tests for RLS when behavior depends on Postgres policies                                                                                                                                                                        | Assert RLS correctness using only a mocked Supabase client                                                                                                                                                           |
| Regenerate types after schema change (`pnpm supabase:types:local`)                                                                                                                                                                              | Use `getSession()` on the server ([GR-013](../standards/golden-rules.md#gr-013-getclaims-for-server-auth-never-getsession))                                                                                          |

---

## Lifecycle (Always This Order)

1. **Contracts** — Zod schemas and `Request` / `Response` / result types at the
   feature boundary ([Backend](./backend.md)).
2. **RED** — Write failing tests **before** production code that satisfies the
   feature.
3. **Schema (only if persistence/RLS changes)** — Apply DDL on **local**
   Supabase only; then `pnpm supabase:migration:new -- <descriptive_name>` and
   `pnpm supabase db diff -o <path-to-that-migration>` (use
   `pnpm supabase:migration:stamp` if the diff overwrote the header); commit the
   file; run `pnpm supabase:types:local`. Do not invent migration paths by hand
   ([docs/guides/migration-workflow.md](../guides/migration-workflow.md)). In
   the same change set, add or extend **pgTAP** (`supabase/tests/pgtap/`) and/or
   **RLS** tests (`packages/supabase-infra` patterns) per
   [Database — Migration test delta](./database.md#migration-test-delta-required);
   verify with `pnpm test:sql` / `pnpm test:rls` as needed
   ([Testing](./testing.md)).
4. **GREEN** — Implement mappers, repositories, domain, then server actions /
   hooks per [Backend](./backend.md).
5. **Integration gate (DB/RLS)** — Add or extend tests that hit **local**
   Supabase with realistic roles ([Testing](./testing.md)). Unit tests alone are
   **not** sufficient for policy correctness. If step 3 already added the
   required test delta, keep it green here; otherwise treat step 5 as
   incomplete.
6. **REFACTOR** — Keep tests green; no behavior change.

---

## Branch: Feature Does Not Need a Schema Change

- **RED:** Unit tests against pure logic and/or **repository ports**
  (interfaces) with test doubles **only** when semantics match Postgres (no
  double that hides RLS).
- **GREEN:** Implement in `@workspace/supabase-data` (or
  `@workspace/supabase-infra` when the change is infra-only) following
  [Backend](./backend.md).
- **REFACTOR** as usual.

---

## Branch: Feature Needs a Schema Change

- **Contracts** first (DTOs, Zod).
- **RED:** Write tests that will fail until the schema exists—prefer integration
  tests behind `pnpm test:integration` once local DB is up, or port-level tests
  that fail with a clear message.
- **Stop** before implementing repositories that assume tables that do not exist
  yet.
- **Schema:** Local DDL → `pnpm supabase:migration:new -- <name>` →
  `pnpm supabase db diff -o <that-file>` → commit migration →
  `pnpm supabase:types:local` → **test delta** in
  [`supabase/tests/pgtap/`](../../supabase/tests/pgtap/) and/or RLS tests per
  [Database](./database.md#migration-test-delta-required).
- **GREEN:** Implement infrastructure and wire tests to real local DB where
  policies matter.
- **Integration:** RLS tests **required** before merge
  ([Testing](./testing.md)); confirm `pnpm test:sql` / `pnpm test:rls` /
  `pnpm test:db` (pgTAP) when migrations or authz-sensitive SQL changed.

---

## Decision Tree

| Situation                                    | Action                                                                                                 |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Unsure if DB change is needed                | Assume yes; read [Database](./database.md); add an integration test that fails until schema exists.    |
| Test fails because a table/column is missing | Complete the schema phase (local DDL + CLI diff + types). Do not mock the schema into correctness.     |
| Test fails only on RLS                       | Fix policies in **local** DB, then new migration via `migration:new` + `db diff -o`; extend RLS tests. |
| Unsure about test type                       | Use [Testing](./testing.md) matrix: unit vs integration vs `pnpm test:rls` / `pnpm test:sql`.          |

---

## Local verification and database tests

This template does **not** ship continuous integration. Locally, `pnpm lint`,
`pnpm typecheck`, `pnpm check:forbidden`, and `pnpm test:coverage` are the usual
quality gates; they do **not** run `pnpm test:integration`, `pnpm test:rls`,
`pnpm test:sql`, or `pnpm test:db`.

**Database scripts (root `package.json`):** [`pnpm test:db`](./testing.md) runs
pgTAP (`supabase test db`). [`pnpm test:sql`](./testing.md) is
`pnpm test:integration && pnpm test:rls` (Vitest).
[`pnpm test:db:all`](./testing.md) runs all three in sequence: integration, RLS,
then pgTAP. Typical preparation is Supabase up + `db reset` before the first
DB-backed run; see [Testing](./testing.md) for environment details.

**When to run DB tests locally:** any change to migrations, RLS policies, RPCs
or SQL functions, or authz-sensitive data access where correctness depends on
Postgres — use `pnpm test:db`, `pnpm test:rls`, `pnpm test:sql`, or
`pnpm test:db:all` as appropriate. Unit coverage and lint are not sufficient for
policy correctness.

---

## Violations

Detected by: local runs of `pnpm test:coverage`, ESLint (`no-restricted-imports`
in apps), `pnpm check:forbidden`, coverage thresholds
([GR-007](../standards/golden-rules.md#gr-007-test-coverage-thresholds)),
and—when you run them—`pnpm test:db` (pgTAP), `pnpm test:sql`, `pnpm test:rls`,
or `pnpm test:db:all` (all three).

---

## Related

- [Testing](./testing.md) — Vitest, colocation, coverage, RLS suites;
  [pre-merge checks](./testing.md#pre-merge-checks-local)
- [Database](./database.md) — Migrations, RLS, functions
- [Backend](./backend.md) — Layers, repositories, actions
- [docs/standards/anti-patterns.md](../standards/anti-patterns.md) — BAD-006
  (happy-path-only tests), BAD-015, BAD-017
