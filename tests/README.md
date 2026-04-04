# Centralized test tree

First level under `tests/` is split by **kind** so it does not mirror the
monorepo layout twice:

| Branch                   | What runs here                                                                                     |
| ------------------------ | -------------------------------------------------------------------------------------------------- |
| **`tests/unit/`**        | Fast suites: no real Postgres. Workspace package tests, app helpers, and Next route-handler tests. |
| **`tests/integration/`** | Local Supabase + real DB (`*.integration.test.ts`).                                                |
| **`tests/rls/`**         | Row-level security (`*.rls.test.ts`).                                                              |
| **`tests/mocks/`**       | Shared fixtures not worth a workspace package.                                                     |

There is no root Playwright (or other) e2e tree here.

## `tests/unit/` layout

| Path                | Purpose                                                                                                                                                                                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tests/unit/<pkg>/` | Workspace **package** tests: same folder name as `packages/<pkg>/`. Mirror that package’s tree (usually under `src/`): suffix path + basename match the module under test.                                                               |
| `tests/unit/<app>/` | **Next.js app** tests: same folder name as `apps/<app>/`. Mirror `apps/<app>/` — route handlers, `_lib`, route groups, etc. live under the **same relative paths** as in the real app (similar to Java `src/test` mirroring `src/main`). |

Package example:

```text
packages/foo/src/session/get-claims.ts
tests/unit/foo/src/session/get-claims.test.ts
```

App example (route handler and colocated `_lib`):

```text
apps/example/app/(auth-handlers)/callback/route.ts
tests/unit/example/app/(auth-handlers)/callback/route.test.ts

apps/example/app/(auth)/_lib/auth-form-schemas.ts
tests/unit/example/app/(auth)/_lib/auth-form-schemas.test.ts
```

The app’s `vitest.config.ts` should **`include`**
`../../tests/unit/<app>/**/*.test.{ts,tsx}` (see `apps/example`). Do **not**
split app tests into separate `handlers/` vs `apps/` trees — one mirror per
deployable.

**Integration and RLS** stay outside `unit/`: `tests/integration/<pkg>/`,
`tests/rls/<pkg>/`. Same `<pkg>` naming rule. They are executed only from the
**`@workspace/tests`** workspace package (`tests/package.json` →
`pnpm test:integration` / `pnpm test:rls` at the repo root via Turbo). Product
packages (`@workspace/supabase-data`, etc.) do **not** declare
`@workspace/test-utils` or own integration Vitest configs.

### Shared helpers

- **`@workspace/test-utils`** — Supabase test clients, env bootstrap,
  assertions; imported by files under `tests/integration/` and `tests/rls/`.
  Vitest setup files (`setup-node`, `setup-dom`, `setup-db`) are loaded via
  **`@workspace/vitest-config`** (resolved with a repo-relative path to avoid a
  workspace cycle — do not add `test-utils` as a dependency of product packages
  for this).
- **`@workspace/supabase-auth/testing/access-control-template`** — Baseline role
  slugs + example JWT permission string for access tests (aligned with seed +
  `shared/permission`).
- **`tests/mocks/`** — One-off doubles or JSON fixtures when you do **not** want
  a package dependency.

Do not scatter `test-helpers.ts` next to production files unless they are
**imported only by tests** and colocation is unavoidable; prefer `tests/mocks/`
or `test-utils`.

## Package-local exceptions (minimal colocation)

Vitest runs each workspace package with `root` set to **that package**. Tests
under `tests/unit/...` can lose correct **`vi.mock` hoisting** for some
dependencies (`next/*`, `@supabase/ssr`, `@supabase/supabase-js`, nested
workspace modules). Moving Vitest `root` to the monorepo root fixes mocks but
**breaks** `next/server`, `next/headers`, etc.

So a **small, explicit** set of files stays as `*.test.ts` **next to the
source** inside the package. Each package’s `vitest.config.ts` lists **both**
`../../tests/unit/<pkg>/**` and these paths.

| Package                     | Colocated test files (do not duplicate under `tests/`)                                                                                                                 |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@workspace/supabase-auth`  | `src/browser/create-browser-auth-client.test.ts`, `src/proxy/update-session.test.ts`, `src/server/create-server-auth-client.test.ts`, `src/session/get-claims.test.ts` |
| `@workspace/supabase-infra` | `src/clients/create-admin-client.test.ts`                                                                                                                              |

Adding a new exception requires a short rationale in the package
`vitest.config.ts` comment and an update to this table.

## Imports

Each package or app configures Vitest aliases (for example `@src/*` → that
package’s `src`, `@/` → app root). Prefer those aliases over long relative paths
from `tests/` into `src/`.

## Running tests

From the **repository root**, use `pnpm test` / `pnpm test:coverage` so
`dotenv-cli` loads [`.env.test`](../.env.test) (see root `package.json`).
Running `vitest` only inside a package without those env vars will fail suites
that read `NEXT_PUBLIC_*` at module scope or in code paths not covered by mocks.

## Related

- [docs/architecture/testing.md](../docs/architecture/testing.md) — commands,
  coverage, integration vs unit.
- [docs/standards/golden-rules.md](../docs/standards/golden-rules.md#gr-008-test-file-layout-centralized--rare-colocation)
  — GR-008.
