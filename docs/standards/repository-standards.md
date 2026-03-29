# Repository standards (canonical)

**Status:** Source of truth for how this monorepo is built, organized, and changed.  
**Audience:** Human contributors and automated agents.  
**Supersedes:** Informal or duplicated guidance elsewhere when there is a conflict—**this file + the linked deep docs win**.

**Read order for agents (mandatory):**

1. This document (skim sections relevant to the task).
2. [AGENTS.md](../AGENTS.md) (workflow, remote DB rules, commit pipeline).
3. [TDD.md](../architecture/tdd.md) and [TESTING.md](../architecture/testing.md) before shipping code.
4. [ARCHITECTURE.md](../architecture/system.md) and [BACKEND.md](../architecture/backend.md) for boundaries.
5. [DATABASE.md](../architecture/database.md) and [docs/guides/migration-workflow.md](../guides/migration-workflow.md) for persistence.
6. [docs/standards/golden-rules.md](./golden-rules.md) and [docs/standards/anti-patterns.md](./anti-patterns.md) for rule IDs.

---

## 1. Repository philosophy

### What this repo optimizes for

- **Predictable boundaries:** Apps are thin; shared packages own auth, data access, and reusable UI contracts.
- **Pinned stack:** Next.js 16, React 19, Tailwind CSS v4, shadcn/ui (via CLI in `packages/ui`), Zod v4, TanStack (Query / Table / Form where used), Supabase — see **[docs/reference/stack.md](../reference/stack.md)** before adding or upgrading dependencies.
- **Migration safety:** Database changes are **CLI-generated only**; tests and types track schema.
- **Explicit imports:** No barrel files; subpath exports only (see §3).
- **Local-first verification:** Development and automated checks assume **local Supabase** unless a task explicitly requires otherwise.

### Consistency expectations

- **One canonical pattern** per concern (data access, auth, forms, tests). Parallel ad-hoc patterns are technical debt.
- **Documentation must match code.** If the code cannot yet match [ARCHITECTURE.md](../architecture/system.md) / [BACKEND.md](../architecture/backend.md), document the gap in PRs and prefer small follow-ups over silent drift.

### How agents must behave

- **Read before edit:** Minimum list above; do not invent package layouts.
- **Do not refactor casually:** No drive-by renames, no “cleanup” outside the task, no new global patterns without updating this doc or the linked standard.
- **Preserve invariants:** Zero-barrel imports; no `apps/*/lib/db` or `lib/repositories`; no `getSession()` on server paths (see `scripts/ci/check-forbidden.mjs`); CLI-only migrations.

### Why local deviation is discouraged

Drift breaks grep-based audits, ESLint assumptions, and RLS tests. **Standardization is a product feature** for a monorepo.

---

## 2. Architecture and boundaries

### Monorepo layout (truth)

| Area            | Path                                     | Role                                                                                                         |
| --------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Apps            | `apps/example` (rename when you ship)     | Next.js applications (UI, routing, thin glue only).                                                          |
| Shared packages | `packages/*` published as `@workspace/*` | `supabase-auth` / `supabase-data` / `supabase-infra` stack, UI primitives, brand UI, forms, tooling configs. |
| Tests           | `tests/`                                 | `tests/unit/`, `tests/integration/`, `tests/rls/` — see [`tests/README.md`](../../tests/README.md).                                                                         |
| DB & migrations | `supabase/`                              | Migrations, seeds, SQL tests—**only** `pnpm supabase:migration:new` + CLI capture (`db diff -o`); see [docs/guides/migration-workflow.md](../guides/migration-workflow.md). |
| Docs            | `docs/`, root `*.md`                     | Standards, ADRs, agent entrypoints.                                                                          |

**Applications (current):**

| App      | Port (dev) | Purpose                                                                                               |
| -------- | ---------- | ----------------------------------------------------------------------------------------------------- |
| `example` | 3000      | Template app: marketing (`/`), auth (`/sign-in`, callbacks, MFA, password reset). |

Post-login URLs and role handling: implement in `@workspace/supabase-auth` (see `app-destination.ts`) and document env URLs in root [`.env.example`](../.env.example).

### Package responsibilities (must not mix)

| Package                     | Owns                                                                                            | Must never own                                               |
| --------------------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `@workspace/supabase-auth`  | Session/JWT claims, guards, proxy session refresh, client auth helpers                          | Raw SQL, business tables, `@workspace/supabase-data` imports |
| `@workspace/supabase-data`  | Repositories, mappers, domain DTOs/ports for data modules, server actions surface, wire schemas | Auth policy decisions duplicated from JWT (use auth package) |
| `@workspace/supabase-infra` | Service-role client helpers, generated DB types path                                            | App-specific UI                                              |
| `@workspace/ui`             | shadcn primitives (CLI-installed only)                                                          | Product/business components                                  |
| `@workspace/brand`          | Shared **hand-written** multi-app UI building on `@workspace/ui`                                | One-off page-only hacks that belong in an app                |
| `@workspace/forms`          | TanStack Form + Zod field helpers shared across apps                                            | Server-only secrets                                          |

### Dependency matrix (workspace)

`@workspace/supabase-infra`, `@workspace/supabase-auth`, and `@workspace/supabase-data` form a **directed acyclic graph (DAG)**. That keeps Turbo/pnpm resolution predictable and avoids **circular dependencies** between infra, session/claims, and the data layer.

**Mental model:** `@workspace/supabase-infra` is the **infra leaf** (public/server env, generated `Database` types, typed Supabase clients—no domain queries). `@workspace/supabase-auth` owns identity and session; among workspace data packages it may depend **only** on `@workspace/supabase-infra`. `@workspace/supabase-data` owns persistence, repositories, and server actions and may depend on **both** `@workspace/supabase-infra` and `@workspace/supabase-auth` (e.g. claims, `createServerAuthClient`) at server boundaries.

| From → To                   | `@workspace/supabase-infra`                                                                                       | `@workspace/supabase-auth`       | `@workspace/supabase-data` |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------- | -------------------------- |
| **Apps**                    | Prefer going through `@workspace/supabase-auth` / `@workspace/supabase-data`; direct import only for rare tooling | Yes                              | Yes                        |
| `@workspace/supabase-infra` | —                                                                                                                 | **No**                           | **No**                     |
| `@workspace/supabase-auth`  | Yes (env, types, typed clients)                                                                                   | —                                | **No**                     |
| `@workspace/supabase-data`  | Yes (admin client, types)                                                                                         | Yes (claims, server auth client) | —                          |

**Absolute prohibition:** `@workspace/supabase-infra` must **never** import `@workspace/supabase-auth` or `@workspace/supabase-data` (the historical source of cycle risk with devDependencies and tests).

**Auth must not import the supabase data package:** `@workspace/supabase-auth` must **not** import `@workspace/supabase-data` (actions, modules, repositories). The **only** future exception would be an explicit **`@workspace/supabase-data/infra/*`** (or equivalent) subpath if infra is merged under the supabase package; until then, auth consumes infra **only** via `@workspace/supabase-infra`.

**Tests:** Integration and RLS suites live under `tests/integration/<pkg>/` and `tests/rls/<pkg>/` and are executed by the **`@workspace/tests`** package (`tests/package.json`); product Supabase packages do **not** list `@workspace/test-utils` or host `vitest.integration` configs. See [TESTING.md](../architecture/testing.md). Those paths do **not** mean `@workspace/supabase-infra` depends on `@workspace/supabase-data`.

### Server vs client

- **Default Server Components** in `app/`. Add `'use client'` only where browser APIs, local state, or client-only libraries require it.
- **Server actions and repository code** live under `packages/supabase-data` (and related packages), marked `server-only` where applicable—not under `apps/*/app` as a pattern.
- **Forbidden:** `getSession()` for authorization decisions on the server (use `getClaims()`). Enforced by convention + `pnpm check:forbidden`.

### Domain vs UI vs infra

- **Domain DTOs and ports:** `packages/supabase-data/src/modules/<module>/domain/`.
- **Supabase-specific implementations:** `.../infrastructure/repositories/`, `.../infrastructure/mappers/`.
- **Presentation:** `apps/*/app`, `apps/*/components`, `@workspace/brand`. **No** `Database["public"]["Tables"][...]` types in domain DTO files.

### Request boundary (Next.js 16)

- Apps use root **`proxy.ts`** (not `middleware.ts`) for session/cookie refresh. Example: [apps/example/proxy.ts](../apps/example/proxy.ts).

---

## 3. File and folder conventions

### Naming

- **Files:** `kebab-case` for routes and most files (`get-profile-by-user-id.ts`). React components: `PascalCase.tsx` when they export a component as the primary symbol.
- **Route-private helpers:** Under `app/`, use underscore prefixes per [GR-003](./golden-rules.md#gr-003-private-directory-convention): `_components`, `_hooks`, `_lib`, `_actions` (not all apps use every slot; **new** route-local code must use this pattern).
- **Tests:** Unit defaults under [`tests/unit/`](../../tests/README.md): `tests/unit/<pkg>/` mirrors `packages/<pkg>/`; `tests/unit/<app>/` mirrors `apps/<app>/` (same relative paths as the deployable). See [TESTING.md](../architecture/testing.md) and [GR-008](./golden-rules.md#gr-008-test-file-layout-centralized--rare-colocation). Integration: `tests/integration/<pkg>/`; RLS: `tests/rls/<pkg>/`. Package-local `*.test.ts` for Vitest mock hoisting: [`tests/README.md`](../../tests/README.md) § Package-local exceptions.

### Three-level documentation layout

| Location | Purpose | Examples |
|----------|---------|----------|
| **`docs/`** (repo root) | **Template & engineering** — valid for any fork; no product domain | AGENTS, stack, golden rules, Supabase setup, migration/TDD policy, CI |
| **`apps/docs/`** | **Product / business in general** — spans multiple apps or describes the product as a whole | Domain glossary, cross-app flows, shared roles/entities, org-wide product notes |
| **`apps/<app>/docs/`** | **Single-app domain** — only that Next.js app | Route inventory, app-specific features, runbooks for that deployable |

**LLM / contributor rule of thumb:** template mechanics → root `docs/`; **business that applies broadly across apps** → `apps/docs/`; **details tied to one app’s domain** → `apps/<app>/docs/`.

- Maintain **`apps/docs/README.md`** (Level 2) and **`apps/<app>/docs/README.md`** in each app (Level 3). See [GR-019](./golden-rules.md#gr-019-three-level-documentation-layout).

### Where new code goes

- **New page or feature in an app:** `apps/<app>/app/...` + route-local `_components` / `_lib` as needed.
- **New persisted entity or mutation:** Extend `@workspace/supabase-data` with a module under `src/modules/<name>/` and actions under `src/actions/<name>/`; **register every new public file** in `packages/supabase-data/package.json` → `exports`.
- **New shadcn primitive:** Add only via CLI into `packages/ui` (see §7). **Do not hand-edit** primitive source except through CLI upgrades.

### Shared abstractions

- **Create** a shared abstraction when **two apps** or **two routes** need the same behavior and it is not a one-off.
- **Do not** create a shared wrapper whose only job is re-exporting a single import to avoid typing—fix types or duplicate trivially until a real second use appears.

### Zero-barrel policy ([GR-001](./golden-rules.md#gr-001-zero-barrel-policy))

- **No** `index.ts` re-export barrels.
- **Imports** use explicit package subpaths: `@workspace/ui/components/button`, `@workspace/supabase-data/actions/...`, etc.
- **Enforcement:** ESLint `no-restricted-imports` for app → `@supabase/supabase-js`; review for barrels.

---

## 4. React and Next.js patterns

### Server Components

- Fetch in RSC where possible; pass serializable props to clients.
- **Do not** import server-only modules into client components (build will fail or mark boundaries incorrectly—treat failures as correctness).

### Routing

- **`example`** is the template app (marketing, auth). Document any non-obvious role → URL rules in `apps/example/README.md` or a short ADR.
- Keep auth callback routes minimal and aligned with [docs/guides/supabase-setup.md](../guides/supabase-setup.md).

### Hooks

- **TanStack Query:** Use for client data that needs cache/mutations when patterns exist in `@workspace/supabase-data` or the app; invalidate or optimistic-update per [docs/guides/client-ui-data-sync.md](../guides/client-ui-data-sync.md) ([GR-017](./golden-rules.md#gr-017-client-ui-auto-sync-and-optimistic-updates)).

### Side effects

- Prefer **`useEffect`** only for real browser subscriptions; avoid fetching in `useEffect` when RSC or query hooks can own the data.

### Anti-patterns

- **Fat client pages** duplicating server validation—validate on server; use Zod on both sides only when UX needs instant feedback.
- **Full-page reload** after mutations as the default ([GR-017](./golden-rules.md#gr-017-client-ui-auto-sync-and-optimistic-updates)).

---

## 5. TypeScript rules

### Compiler baseline (actual config)

- Shared config: `packages/typescript-config/base.json` extends with `strict: true`, `noUncheckedIndexedAccess: true`.
- **Note:** Some docs mention `exactOptionalPropertyTypes` and additional flags that are **not** enabled in the committed `base.json`. Treat those as **aspirational** until added repo-wide; do not assume they are active in CI.

### Optional and undefined

- Prefer **explicit** optional properties with clear defaults at boundaries; avoid `as` casts ([GR-006](./golden-rules.md#gr-006-parse-at-boundaries)).

### Public interfaces

- Server actions: **discriminated unions** or documented `ActionResult` shapes ([BACKEND.md](../architecture/backend.md)); **never** expose `neverthrow` `Result` or non-serializable objects to the client.
- **Parse at boundaries** with Zod (`safeParse` / `parse`) for `unknown` inputs.

### Unsafe patterns (disallowed)

- `as` on external JSON or Supabase rows at trust boundaries.
- `getSession()` in server code paths for security-sensitive decisions ([GR-013](./golden-rules.md#gr-013-getclaims-for-server-auth-never-getsession)).

---

## 6. Data and validation rules

### Zod

- **Zod 4** is in use (`zod` dependency). Wire schemas live next to modules (e.g. `domain/schemas/*.schema.ts`).
- **All untrusted input** to server actions: validate before repository calls.

### Validation boundaries

- **HTTP / Server Actions:** Validate at the entry of the action.
- **Repositories:** Accept typed DTOs or primitives already validated; do not parse arbitrary `unknown` deep inside repositories unless the boundary is clearly internal.

### Server actions (implemented pattern)

- Actions are **plain async functions** in `packages/supabase-data/src/actions/...`, `import "server-only"` where appropriate, exported via **explicit** `package.json` exports.
- **Current code** uses project-specific discriminated unions (e.g. `{ ok: true; data } | { ok: false; error }`). **[BACKEND.md](../architecture/backend.md)** describes a richer `createAction` / `serializeResult` pattern—**that helper stack is not present in the tree yet**. New work must still: parse with Zod, keep types serializable, and follow repository layout. When `createAction` lands, migrate new actions to it without inventing a third pattern.

### Database access

- **Only** inside `EntitySupabaseRepository` (or named `*-supabase.repository.ts`) classes under `infrastructure/repositories/`.
- **Apps:** Do not import `@supabase/supabase-js` (ESLint blocks in apps).

### Serialization

- Return JSON-safe data to clients; no `Date` objects unless consistently handled; prefer ISO strings at boundaries if needed.

---

## 7. UI and styling rules

### Tailwind

- **Tailwind v4** with `@tailwindcss/postcss` in apps; follow existing `app/globals.css` / theme tokens per app.

### Design system

- **Primitives:** `@workspace/ui` — install with shadcn CLI targeting **`packages/ui`**:

  ```bash
  pnpm dlx shadcn@latest add <component> -c packages/ui
  ```

- **Product compositions:** `@workspace/brand` importing `@workspace/ui/components/*`.
- **Forms:** `@workspace/forms` (TanStack Form + Zod) for shared field machinery; apps compose forms with RHF where already established (`apps/example`)—**do not** split one screen across two form frameworks without an ADR.

### Theming

- Use CSS variables / tokens already in the app; no one-off hex spaghetti in feature code unless matching an existing design token pattern.

### Visual drift anti-patterns

- Copy-pasting shadcn into apps—**forbidden**; use `packages/ui` or `packages/brand`.
- **Editing** `packages/ui/src/components/*` for product logic—**forbidden** ([AGENTS.md](../AGENTS.md)).

---

## 8. Error handling and observability

### Modeling

- **User-facing:** Short, translatable `error` strings or structured field errors from Zod; no stack traces to clients.
- **Internal:** Use repository-level errors (`@workspace/supabase-data` lib where present); emit structured events through `@workspace/logging`. Raw `console.*` is forbidden in product code ([GR-005](./golden-rules.md#gr-005-no-console-in-production)).

### Throw vs return

- **Server actions:** Prefer **returning** `{ ok: false, error }` or typed `ActionResult` per [BACKEND.md](../architecture/backend.md)—avoid throwing across the server action boundary unless Next.js error boundaries are intentionally used.

### Correlation / observability

- **Use one package:** `@workspace/logging` is the only shared observability package.
- **Seed at ingress:** Correlation starts in `apps/*/proxy.ts` and is forwarded via request headers.
- **Keep business logic clean:** Do not pass trace or correlation IDs through DTOs unless the contract itself is external.
- **Protect sensitive data:** Never log raw auth headers, cookies, JWTs, OTPs, service role keys, or uncontrolled payloads.
- **Privileged operations:** Service-role or admin-style mutations must emit structured observability events.
- **Canonical doc:** [docs/guides/observability-architecture.md](../guides/observability-architecture.md)

---

## 9. Testing expectations

### Commands

- See root [package.json](../package.json): `pnpm test`, `pnpm test:integration`, `pnpm test:rls`, `pnpm test:sql`, `pnpm test:coverage`.

### What to test

- **Unit:** Pure logic, mappers, validators, auth helpers.
- **Integration / RLS:** Real local Supabase; **never** claim RLS from mocks alone ([TESTING.md](../architecture/testing.md), [BAD-006](./anti-patterns.md#bad-006-happy-path-only-tests)).

### Coverage

- Thresholds enforced via `@workspace/vitest-config` when running coverage ([GR-007](./golden-rules.md#gr-007-test-coverage-thresholds)).

### Missing tests

- **Not acceptable** for new auth, money, PII, or RLS-sensitive paths—add tests with the feature ([TDD.md](../architecture/tdd.md)).

---

## 10. Documentation and ADRs

### What must be documented

- **New app or package:** README in the folder + link from root [README.md](../README.md) or [apps/README.md](../apps/README.md) / `packages/README.md`.
- **New cross-cutting standard:** Update **this file** or the relevant root doc; add ADR if the decision is non-obvious or costly to reverse.

### Where things live

- **Operational contract (this file):** Repo-wide rules.
- **Deep dives:** [ARCHITECTURE.md](../architecture/system.md), [BACKEND.md](../architecture/backend.md), [DATABASE.md](../architecture/database.md).
- **Rule IDs:** [golden-rules.md](./golden-rules.md), [anti-patterns.md](./anti-patterns.md).

### Stale docs

- If you change behavior, **update the doc in the same PR**. ADR-001 describes historical Vite-era layout—see banner in that file; **current** layout is this document + [ARCHITECTURE.md](../architecture/system.md).

---

## 11. Agent operating rules (checklist)

1. Read **this file** and [AGENTS.md](../AGENTS.md).
2. Follow **TDD.md** order for features touching DB.
3. **Never** create migration files without `pnpm supabase:migration:new` ([GR-015](./golden-rules.md#gr-015-cli-generated-migrations-only-critical---human-confirmation-required)).
4. **Never** point automation at remote Supabase for writes without human approval ([AGENTS.md](../AGENTS.md)).
5. Run **`pnpm workflow`** (or `lint` + `typecheck` + `build` + `format`) before claiming done.
6. **Do not** add barrels, app-local DB layers, or server `getSession()`.

---

## 12. Change management

### Introducing a new convention

1. Propose in a PR with updates to **this document** (or the relevant canonical doc).
2. Link from [AGENTS.md](../AGENTS.md) if it affects agents.
3. If replacing an old pattern, add a **short migration note** and deadline or cleanup issue.

### Deprecating a pattern

- Mark in [anti-patterns.md](./anti-patterns.md) or a “Deprecated” subsection in the relevant doc; grep for usages; remove in focused PRs.

### Preventing parallel standards

- **Code review + this document.** If two approaches appear, pick one, document it here, and schedule removal of the other.

---

## Appendix A — Audit snapshot (2026-03-25)

### Healthy patterns to keep

- pnpm workspaces + Turborepo; root `dotenv-cli` for env-aware scripts.
- Explicit `@workspace/supabase-data` exports; no barrels.
- Route `proxy.ts` for session refresh.
- Centralized tests: `tests/unit/`, `tests/integration/<pkg>/`, `tests/rls/<pkg>/`.
- ESLint ban on `@supabase/supabase-js` in apps.

### Consolidation / drift identified

- **Historical note:** older drafts referenced legacy scope names; current imports use `@workspace/*` per [GR-001](./golden-rules.md#gr-001-zero-barrel-policy).
- **README** shadcn instructions pointed at `apps/web`—replaced with `packages/ui`.
- **GR-004 / AGENTS** claimed flags not present in committed `tsconfig`—aligned text to actual `base.json` or marked aspirational.
- **BACKEND.md** `createAction` / `serializeResult` examples describe a **target** API not yet in `packages/supabase-data/src/lib`—actions today follow manual patterns; must converge when helpers exist.
- **`packages/README.md`** was missing—added.

### Follow-up (optional migrations)

- Implement shared `createAction` / `serializeResult` in `@workspace/supabase-data` and migrate actions to reduce one-off unions.
- Enable stricter TypeScript flags (e.g. `exactOptionalPropertyTypes`) repo-wide with a dedicated fix PR.
- Add ESLint `max-lines` if [GR-002](./golden-rules.md#gr-002-file-size-limit) should be machine-enforced (currently documented, not verified in sampled `eslint.config`).

---

**Last reviewed:** 2026-03-25
