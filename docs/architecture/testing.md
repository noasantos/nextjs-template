# Testing Standards

Mechanics for Vitest, coverage, and database-backed tests. **Process** (RED/GREEN/REFACTOR and migration order) lives in [TDD](./tdd.md).

---

## Runner and Commands

| Command | Purpose |
|---------|---------|
| `pnpm test` | Fast unit tests via Turborepo (`vitest run`) |
| `pnpm test:coverage` | Unit tests with coverage enabled (`turbo run test -- --coverage`) |
| `pnpm test:watch` | Watch mode |
| `pnpm test:integration` | Integration tests (local Supabase; see below) |
| `pnpm test:rls` | RLS-focused suites |
| `pnpm test:sql` | `pnpm supabase test db` (pgTAP / SQL tests) |
| `pnpm test:db` | After `pnpm test:integration:prepare`: integration + RLS + SQL (`test:integration`, `test:rls`, `test:sql`). |
| `pnpm test:all` | Full suite: `test:coverage` then DB-backed tests (`test:integration`, `test:rls`, `test:sql`). |

Shared config: `@workspace/vitest-config` ([packages/vitest-config](../../packages/vitest-config/README.md)). Root `pnpm test*` commands are **Turbo-driven** and execute each workspace package/app's own `test` or `test:integration` script from its `package.json`; [vitest.config.mts](../../vitest.config.mts) is only a convenience for direct multi-project Vitest runs and is **not** the source of truth for root test execution.

### Pre-merge checks (local)

GitHub Actions now cover quality gates, dependency review, CodeQL, and a DB/RLS verification path, but local verification is still required before claiming a change is ready. Run `pnpm workflow` from the repo root, plus `pnpm check:forbidden`, `pnpm check:docs-drift`, `pnpm test:coverage`, and, when migrations or RLS matter, `pnpm test:integration:prepare` then `pnpm test:db`. See [AGENTS.md](../../AGENTS.md) → Commit workflow.

---

## Coverage Thresholds ([GR-007](../standards/golden-rules.md#gr-007-test-coverage-thresholds))

Shared numeric minimums are enforced by `@workspace/vitest-config` ([packages/vitest-config/src/node.ts](../../packages/vitest-config/src/node.ts) and [packages/vitest-config/src/react.ts](../../packages/vitest-config/src/react.ts)):

- Lines ≥ 80%, statements ≥ 80%, branches ≥ 75%, functions ≥ 80%

Thresholds apply **per Vitest project** to that project’s **configured coverage scope** (see [GR-007](../standards/golden-rules.md#gr-007-test-coverage-thresholds) for scoped coverage, `coverageInclude`, and known blind zones such as the narrow `apps/example` scope, selective `supabase-data` actions, and selective shared UI coverage).

Coverage thresholds apply whenever you run `pnpm test:coverage` (fails locally if below minimums).

**Apps with narrow `coverageInclude`:** `apps/example` scopes coverage thresholds to explicit file globs only ([apps/example/vitest.config.ts](../../apps/example/vitest.config.ts)). Most UI and routes are outside that scope, so passing the shared thresholds does not imply whole-app coverage—only the listed paths.

**Package `@workspace/supabase-data`:** Coverage thresholds apply only to paths listed in [packages/supabase-data/vitest.config.ts](../../packages/supabase-data/vitest.config.ts) (`coverageInclude`). Today that is a **subset** of [packages/supabase-data/src/actions/](../../packages/supabase-data/src/actions/) and related modules (e.g. profiles, user roles, `sync-user-access`) plus shared helpers such as `src/lib/supabase-repository-error.ts`. Other actions under `src/actions/*` and most of the package are **outside** unit coverage scope unless added to `coverageInclude` with tests. Integration tests live under [`tests/integration/supabase-data/`](../../tests/integration/supabase-data) and run via [`@workspace/tests`](../../tests/package.json) (`tests/vitest.integration.config.ts`); they are excluded from the unit project’s coverage collection by convention.

**Package `@workspace/ui`:** Root `pnpm test:coverage` **does** execute `@workspace/ui` via Turbo ([package script](../../packages/ui/package.json)), but thresholds only measure the four files listed in [packages/ui/vitest.config.ts](../../packages/ui/vitest.config.ts). Shared UI outside that include list is unmeasured until added explicitly.

---

## Where unit tests live ([GR-008](../standards/golden-rules.md#gr-008-test-file-layout-centralized--rare-colocation))

- **Default:** root [`tests/`](../../tests/README.md). **Unit** tests live under **`tests/unit/`**: workspace packages use `tests/unit/<pkg>/...` mirroring `packages/<pkg>/`; each Next app uses **`tests/unit/<app>/...` mirroring `apps/<app>/`** (one tree per app — handlers, `_lib`, etc. follow the same paths as in the app).
- **Shared helpers:** DB/integration helpers live in [`@workspace/test-utils`](../../packages/test-utils) and are depended on by **`@workspace/tests`** only (not by `@workspace/supabase-data` / `supabase-auth` as product packages). Vitest presets in [`@workspace/vitest-config`](../../packages/vitest-config) load setup files from `packages/test-utils` via a fixed relative path. Use [`tests/mocks/`](../../tests/mocks) for ad-hoc fixtures.
- **Minimal colocation:** a few Vitest suites that mock `next/*`, `@supabase/ssr`, or `@supabase/supabase-js` must stay as `*.test.ts` **inside** the package `src/` (listed in [`tests/README.md`](../../tests/README.md)). Do not duplicate those files under `tests/`.
- **Env:** run **`pnpm test`** from the repo root so `.env.test` is loaded; ad-hoc `vitest` in a package may miss `NEXT_PUBLIC_*` and fail unrelated tests.
- **Integration / RLS:** `tests/integration/<pkg>/**` (`*.integration.test.ts`) and `tests/rls/<pkg>/**` (`*.rls.test.ts`), local Supabase. `<pkg>` is the workspace folder under `packages/` (e.g. `supabase-data`). See [`tests/README.md`](../../tests/README.md).

---

## What to Mock vs Not Mock

| Layer | Mock? | Notes |
|-------|-------|--------|
| Pure domain logic | No | Prefer deterministic unit tests. |
| Repository **port** (interface) | Yes (in-memory / fake) | Only if behavior matches real DB semantics; do not use fakes to “pass” RLS. |
| Supabase client for **RLS correctness** | **No** | Use local Supabase + real JWT/service role per [Database](./database.md). |
| Network / external APIs | Yes | At boundaries with Zod parsing after. |

---

## Integration and RLS

1. Start local Supabase: `pnpm supabase:start` (or use `pnpm test:integration:prepare` from root [package.json](../../package.json)).
2. Reset DB when needed: `pnpm supabase:db:reset`.
3. Use `@workspace/test-utils` helpers for clients/assertions where provided.
4. **RLS:** Tests must use appropriate roles (e.g. authenticated user vs service role) and assert **deny** paths, not only allow ([BAD-006](../standards/anti-patterns.md#bad-006-happy-path-only-tests)).

Never claim RLS is correct based solely on mocked `createClient` returning arbitrary data.

---

## Environment

- Root may use `.env.test` via `dotenv-cli` for `pnpm test` (see [package.json](../../package.json)).
- Document required vars next to integration tests (e.g. `TEST_USER_PASSWORD` in [turbo.json](../../turbo.json) `globalEnv`).

---

## Related

- [TDD](./tdd.md) — Strict lifecycle and DB branches  
- [docs/standards/anti-patterns.md](../standards/anti-patterns.md) — BAD-006 (happy-path-only tests)  
- [AGENTS.md](../../AGENTS.md) — Agent entry and rules  
