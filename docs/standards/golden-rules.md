# Golden Rules

These rules are non-negotiable. Violations must be fixed before merge.

## GR-001: Zero-Barrel Policy

**Rule:** Never create or use barrel files (`index.ts` that re-exports from other files).

**Why:** Hidden dependencies, poor tree-shaking, unclear import sources.

**Enforcement:** ESLint `no-restricted-imports` blocks root package imports.

**Correct:**

```typescript
import { syncUserAccess } from "@workspace/supabase-data/actions/user-access/sync-user-access"
import { Button } from "@workspace/ui/components/button"
```

**Incorrect:**

```typescript
import { syncUserAccess } from "@workspace/supabase-data"
import { Button } from "@workspace/ui"
```

---

## GR-002: File Size Limit

**Rule:** No component file may exceed 250 lines. Warning at 250, error at 300.

**Why:** High cognitive load, side-effect coupling, poor maintainability.

**Enforcement:** ESLint `max-lines` rule.

**Action:** Extract presentational pieces into separate components when approaching limit.

---

## GR-003: Private Directory Convention

**Rule:** Route-local code lives in underscore-prefixed directories: `_components`, `_hooks`, `_utils`.

**Why:** Clear ownership, prevents accidental imports from other routes.

**Structure:**

```
src/routes/dashboard/
  _components/      # Private to dashboard
  _hooks/           # Private to dashboard
  page.tsx          # Route component
```

---

## GR-004: TypeScript Strictness

**Rule:** Shared `tsconfig` enables strict mode and `noUncheckedIndexedAccess`. No exceptions to those baseline flags.

**Currently enabled in [packages/typescript-config/base.json](../packages/typescript-config/base.json):**

- `strict: true`
- `noUncheckedIndexedAccess: true`

**Strongly recommended for future repo-wide tightening (not all enabled yet):**

- `exactOptionalPropertyTypes: true`
- `noImplicitReturns: true`
- `noFallthroughCasesInSwitch: true`

**Why:** Catch bugs at compile time, prevent undefined behavior. Canonical nuance: [docs/standards/repository-standards.md](./repository-standards.md#5-typescript-rules).

---

## GR-005: No Console in Production

**Rule:** Raw `console.log`, `console.warn`, `console.error`, `console.info`, and `console.debug` are banned in product code.

**Why:** Raw console output bypasses correlation, redaction, and event semantics.

**Enforcement:** ESLint `no-console: "error"`. The only approved console usage is inside the shared logging package fallback behavior or CLI-only scripts that are not part of product runtime code.

**Alternative:** Use `@workspace/logging`.

---

## GR-018: Structured Observability via `@workspace/logging`

**Rule:** All new observability code must use `@workspace/logging` for contracts, correlation, redaction, and emission. Do not create app-local or package-local logger helpers.

**Why:** One event contract and one safety model are required for correlation, redaction, and incident response.

**Enforcement:** ESLint restricts the deprecated `@workspace/logging/server-error` import, review rejects local logging helpers, and observability docs define the allowed package surface.

---

## GR-006: Parse at Boundaries

**Rule:** All external data must be parsed with Zod. Never use `as Type` assertions on API responses or user input.

**Why:** Runtime type safety, prevent schema mismatches.

**Enforcement:** ESLint `@typescript-eslint/consistent-type-assertions: "error"`

**Correct:**

```typescript
const parsed = UserSchema.safeParse(apiResponse)
if (!parsed.success) throw new Error("Invalid user data")
const user = parsed.data
```

**Incorrect:**

```typescript
const user = apiResponse as User // Runtime type mismatch risk
```

---

## GR-007: Test Coverage Thresholds

**Rule:** When the coverage-enabled suite runs (`pnpm test:coverage`), each Vitest project must meet these **shared numeric minimums** on its **configured coverage scope** (not on the whole monorepo):

- **Lines** ≥ 80% · **Statements** ≥ 80% · **Branches** ≥ 75% · **Functions** ≥ 80%

The numbers are defined once in `@workspace/vitest-config` ([`src/node.ts`](../packages/vitest-config/src/node.ts) and [`src/react.ts`](../packages/vitest-config/src/react.ts)); Node and React presets use the same `coverage.thresholds`.

**Scoped coverage (critical):** Thresholds apply only to source files Vitest **includes** in coverage for that project. Many apps and packages set `coverageInclude` in their `vitest.config.ts`, which **narrows** which paths count. Passing CI therefore means “included paths meet the bar,” **not** “every file in the repo or every file in that package is covered.” Treat uncovered paths as untested until covered by tests and, where appropriate, added to that project’s include list.

**Known blind zones (non-exhaustive):**

| Area                                | Why it is a blind zone                                                                                                                                                                             |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`packages/ui` (`@workspace/ui`)** | Root `pnpm test:coverage` **does** execute `@workspace/ui` via Turbo ([package script](../packages/ui/package.json)), but thresholds only measure the four files listed in [packages/ui/vitest.config.ts](../packages/ui/vitest.config.ts). |
| **`apps/example`**                  | Deliberately narrow `coverageInclude`; most routes and UI sit outside measured scope ([example vitest.config](../apps/example/vitest.config.ts)). |
| **`packages/supabase-data`**        | Coverage is scoped to an explicit subset of modules/actions (profiles, user roles, user access sync, etc.), not all of `src/**` ([vitest.config](../packages/supabase-data/vitest.config.ts)).            |
| **Example auth routes**             | Auth-specific files are included selectively in [`apps/example/vitest.config.ts`](../apps/example/vitest.config.ts); most UI remains outside measured scope unless added explicitly. |

**Why:** Confidence and regression detection **for the paths we measure**; the bar stays strict without implying false whole-repo completeness.

**Runner truth:** Root `pnpm test` / `pnpm test:coverage` are **Turbo** tasks, so the authoritative participation list is the set of workspace `package.json` test scripts plus each project’s `coverageInclude`, not [vitest.config.mts](../vitest.config.mts).

**Enforcement:** CI fails if any participating project’s thresholds are not met when `pnpm test:coverage` runs. Mechanics: [TESTING.md](../architecture/testing.md).

---

## GR-008: Test file layout (centralized + rare colocation)

**Rule:** **Default:** unit tests live under the root [`tests/`](../../tests/README.md) tree inside **`tests/unit/`**. **Packages:** `tests/unit/<pkg>/...` mirrors `packages/<pkg>/` (usually including `src/`). **Apps:** `tests/unit/<app>/...` mirrors `apps/<app>/` (routes, `_lib`, route groups — same relative paths as production; no separate `handlers/` vs `apps/` buckets). Shared test utilities belong in [`@workspace/test-utils`](../../packages/test-utils) (consumed from integration/RLS suites under `tests/` via [`@workspace/tests`](../../tests/package.json); product packages must not list `test-utils` just to run tests) or `tests/mocks/` for throwaway fixtures. **Exceptions:** keep a `*.test.ts` next to package source **only** for the small set where Vitest’s package `root` + `vi.mock` hoisting requires it (today: heavy mocks of `next/*`, `@supabase/ssr`, `@supabase/supabase-js` — see the table in [`tests/README.md`](../../tests/README.md)). List each exception in that README and in the package `vitest.config.ts` `include` array with a one-line comment.

**Why:** Avoids doubling every `src` file with a sibling test in busy folders; keeps one obvious tree for most tests; exceptions stay documented and minimal.

**Pattern:** Same basename as the module under test: `foo.ts` → `tests/unit/<pkg>/src/.../foo.test.ts` (packages); `route.ts` → `tests/unit/<app>/app/.../route.test.ts` (apps). Use Vitest aliases (`@src/*`, `@/`, `@workspace/*`) instead of long `../../../` chains.

---

## GR-009: Named Async Contracts

**Rule:** API boundary functions define three types: `Request`, `Response`, `Promise`.

**Why:** Explicit contracts, better type inference, clearer error handling.

**Pattern:**

```typescript
export type CreateUserRequest = { name: string }
export type CreateUserResponse = { id: string; name: string }
export type CreateUserPromise = Promise<Result<CreateUserResponse, AppError>>

export async function createUser(req: CreateUserRequest): CreateUserPromise {
  // ...
}
```

---

## GR-010: Agent entry and standards hierarchy

**Rule:** `AGENTS.md` is the **agent entry index** (workflow, links, non-negotiables). **Operational repo contract:** [docs/standards/repository-standards.md](./repository-standards.md). Deep docs under `docs/architecture/` (system, backend, database, TDD, testing) are linked, not duplicated in AGENTS.md.

**Why:** Single navigation hub; standards live in one canonical file plus deep docs.

**Enforcement:** Keep `AGENTS.md` link-heavy; add new cross-cutting rules to `repository-standards.md` (or the relevant root doc), then link from `AGENTS.md`.

---

## GR-016: TDD Process Compliance

**Rule:** Follow [TDD.md](../architecture/tdd.md) for RED→GREEN→REFACTOR, including migration-safe ordering (`pnpm supabase:migration:new` + `pnpm supabase db diff -o …`; no hand-invented migration paths).

**Why:** Aligns tests, schema, and implementation without violating GR-015.

**Enforcement:** Run `pnpm test:coverage` (coverage thresholds per [GR-007](#gr-007-test-coverage-thresholds)), `pnpm check:forbidden`, and related checks locally or in your own pipeline. For migrations and RLS, run `pnpm test:db` when behavior depends on Postgres—see [TESTING.md](../architecture/testing.md).

**Related:** [TESTING.md](../architecture/testing.md), [GR-007](#gr-007-test-coverage-thresholds).

---

## GR-011: Repository Pattern for All Data Access

**Rule:** ALL database access MUST use the repository pattern. NEVER expose raw Supabase queries outside infrastructure layers.

**Why:** Type safety, testability, business logic centralization.

**Structure:**

```
packages/supabase-data/src/modules/{module}/
├── domain/
│   ├── dto/           # EntityDTO, CreateEntityData
│   └── ports/         # Repository interface
└── infrastructure/
    ├── mappers/       # Row → DTO + business logic
    └── repositories/  # Supabase implementation
```

**Enforcement:** Code review, ESLint rules. See **[BACKEND.md → Repository Pattern](../architecture/backend.md#repository-pattern)**.

---

## GR-012: Fluid Compute - New Client Per Request

**Rule:** NEVER create Supabase server clients at module scope. ALWAYS create inside request handlers.

**Why:** Prevents auth leakage between requests in serverless environments.

**Correct:**

```typescript
export async function myAction() {
  const supabase = await createServerAuthClient() // Per-request
  const { data } = await supabase.auth.getClaims()
}
```

**Incorrect:**

```typescript
const supabase = createServerClient(...); // Module scope = LEAKS!
export async function myAction() { /* ... */ }
```

**Enforcement:** Code review, runtime checks. See **[BACKEND.md → Authentication](../architecture/backend.md#authentication)**.

---

## GR-013: getClaims() for Server Auth (Never getSession)

**Rule:** ALWAYS use `getClaims()` for server-side authorization. NEVER use `getSession()` on server.

**Why:** `getClaims()` verifies JWT via cached JWKS. `getSession()` reads cookie without verification.

| Method         | Network            | JWT Verified | Use Case                |
| -------------- | ------------------ | ------------ | ----------------------- |
| `getClaims()`  | JWKS only (cached) | ✅ Yes       | PRIMARY for server auth |
| `getUser()`    | Always (Auth DB)   | ✅ Yes       | Fallback only           |
| `getSession()` | No                 | ❌ No        | NEVER on server         |

**Enforcement:** Code review, linting. See **[BACKEND.md → Authentication](../architecture/backend.md#authentication)**.

---

## GR-014: RLS-First Database Design

**Rule:** ALL tables MUST have Row Level Security (RLS) enabled from creation. Policies must be granular (per operation + role).

**Why:** Security by default, defense in depth.

**Correct:**

```sql
CREATE TABLE entities (...);
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own" ON entities FOR SELECT
  TO authenticated USING (user_id = auth.uid());
```

**Incorrect:**

```sql
CREATE TABLE entities (...);  -- Missing RLS!
```

**Enforcement:** Migration review, CI checks. See **[DATABASE.md → RLS-First Design](../architecture/database.md#rls-first-design)**.

---

## GR-015: CLI-Generated Migrations Only (CRITICAL - HUMAN CONFIRMATION REQUIRED)

**Rule:** **NEVER create new files under `supabase/migrations/` without `pnpm supabase:migration:new -- <name>`.** Capture SQL with the Supabase CLI (`pnpm supabase db diff -o <path-to-that-file>` after local DDL). Do not use `pnpm supabase db diff -f <name>` as the **sole** create step — it skips the stamped workflow.

**Why:** Hand-made paths and unstamped files cause drift, inconsistent metadata, and review gaps.

**Enforcement:** Code review, migration naming conventions, CI checks.

**This is a CRITICAL rule that requires HUMAN confirmation:**

```bash
# ✅ CORRECT: stamped file + diff into same path
pnpm supabase:migration:new -- create_users_table
pnpm supabase db diff -o supabase/migrations/YYYYMMDDHHMMSS_create_users_table.sql
pnpm supabase:migration:stamp -- supabase/migrations/YYYYMMDDHHMMSS_create_users_table.sql   # if header was overwritten

# ❌ FORBIDDEN: inventing the migration path
# touch supabase/migrations/YYYYMMDDHHMMSS_manual.sql
```

**AI Agent Restrictions:**

- **NEVER** suggest creating SQL files in `supabase/migrations/` without `pnpm supabase:migration:new`
- **NEVER** provide SQL to paste into a hand-made migration path
- **ALWAYS** instruct: `migration:new` first, then `db diff -o` to that path
- **ALWAYS** remind that `db diff -f` alone is not the supported create path

**If you need to modify the database:**

1. Make changes in the local database (Studio, psql, etc.).
2. Run `pnpm supabase:migration:new -- <descriptive_name>`, then `pnpm supabase db diff -o <that path>`.
3. Review the file; use `pnpm supabase:migration:stamp` if the header was lost.
4. Commit the migration file.

**See:** [DATABASE.md → Migrations](../architecture/database.md#migrations)

---

## GR-017: Client UI auto-sync and optimistic updates

**Rule:** After mutations, visible UI MUST update **without** a manual full-page refresh. Prefer **cache invalidation** or **optimistic updates** (`invalidateQueries`, `setQueryData`, `revalidatePath`, `revalidateTag` as appropriate). Avoid **global loading screens** for fast actions; use **local pending state** (e.g. button `disabled` / `isPending`).

**Why:** Matches user expectations, reduces perceived latency, and keeps lists and detail views consistent with the server.

**Enforcement:** Code review, PR checklist. See **[docs/guides/client-ui-data-sync.md](../guides/client-ui-data-sync.md)** and [BACKEND.md](../architecture/backend.md).

**Exceptions:** Document when optimism is unsafe (irreversible or regulated flows); use explicit confirmation instead of silent list updates.

---

## GR-019: Three-level documentation layout

Documentation is split by **how broad the audience is** (template vs product vs single app). LLMs and humans must place files in the correct tier.

### Level 1 — Monorepo root `docs/`

**For:** Engineering **template** and **repository** standards only — things that apply to **any** fork: [AGENTS.md](../AGENTS.md), [repository-standards.md](./repository-standards.md), stack contract, TDD/TESTING/DATABASE policy, Supabase local setup, ADRs about repo layout, golden rules, prompts for agents.

**Not for:** Product requirements, domain glossary, business workflows, or stakeholder-facing specs (even if “technical”).

### Level 2 — `apps/docs/`

**For:** **Cross-app product / business** documentation that is **not** template engineering: domain concepts shared by several apps, high-level user journeys, business glossary, org-wide release notes for the **product** surface.

**Not for:** Repo tooling standards (those stay in root `docs/`). **Not for** material that only concerns **one** app (use Level 3).

### Level 3 — `apps/<app>/docs/`

**For:** Documentation **specific to that application’s domain and surface**: route maps, feature notes for that app only, screenshots, deployment/runbooks for that binary, UI copy drafts scoped to that app.

**Rule:** Every Next.js app under `apps/<app>/` **must** have `apps/<app>/docs/` with at least a short `README.md` pointing at this hierarchy.

**Why:** Root `docs/` stays fork-clean; **business-in-general** has one home under `apps/docs/`; **deep per-app** detail stays next to the app.

**Enforcement:** Code review; [apps/docs/README.md](../apps/docs/README.md) explains Level 2; per-app READMEs explain Level 3.

**See:** [docs/standards/repository-standards.md § Three-level documentation](./repository-standards.md#three-level-documentation-layout).
