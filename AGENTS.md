# Turborepo template — Agent Guidelines

**Canonical AI entry.** Start here; deep rules are linked. **TDD (strict, migration-safe):** [docs/architecture/tdd.md](./docs/architecture/tdd.md) · **Tests / Vitest / RLS:** [docs/architecture/testing.md](./docs/architecture/testing.md)

---

## Test trust boundaries (agents)

**Do not treat a green `pnpm test:coverage` alone as proof that database or authorization work is complete.** Unit coverage does **not** replace integration, RLS, or SQL (pgTAP) suites.

If your change touches migrations, RLS, policies, RPCs, or authz-sensitive code, **do not** claim verification or tell the user the work is merge-ready until **`pnpm test:db`** (or the relevant subsets) has been run locally when behavior depends on Postgres—see [docs/architecture/testing.md](./docs/architecture/testing.md).

---

## Execution order (strict) — add-on to workflow below

| Step | Read |
|------|------|
| 1 | [docs/standards/repository-standards.md](./docs/standards/repository-standards.md) (canonical repo contract) |
| 2 | This file |
| 3 | [docs/reference/stack.md](./docs/reference/stack.md) (Next 16, Zod 4, Tailwind 4, TanStack, Supabase — **what is pinned**) |
| 4 | [docs/architecture/tdd.md](./docs/architecture/tdd.md) |
| 5 | [docs/architecture/system.md](./docs/architecture/system.md) |
| 6 | [docs/architecture/backend.md](./docs/architecture/backend.md) (data-layer standards; `@workspace/supabase-infra` = Supabase infra only); [docs/architecture/database.md](./docs/architecture/database.md) (schema/RLS); [docs/architecture/testing.md](./docs/architecture/testing.md) (suites) |
| 7 | [docs/standards/golden-rules.md](./docs/standards/golden-rules.md), [docs/standards/anti-patterns.md](./docs/standards/anti-patterns.md) |

If the feature changes persistence or RLS: [docs/guides/migration-workflow.md](./docs/guides/migration-workflow.md) after [docs/architecture/database.md](./docs/architecture/database.md). **Local Supabase env:** [docs/guides/supabase-setup.md](./docs/guides/supabase-setup.md).

### Decision tree (DB / schema)

| Question | Action |
|----------|--------|
| Needs DB tables/columns/policies? | [docs/architecture/tdd.md](./docs/architecture/tdd.md) schema phase: local DDL → `pnpm supabase:migration:new -- <name>` → `pnpm supabase db diff -o <that-file>` → types → then implementation. |
| Tests fail for missing schema? | Finish schema + types; do not mock DB/RLS into passing. |
| Unsure DB vs RLS? | Integration/RLS tests; [docs/architecture/database.md](./docs/architecture/database.md). |

---

## Critical rules (non-negotiable)

### Migrations — CLI only (GR-015 / BAD-015)

**YOU ARE STRICTLY PROHIBITED FROM CREATING MIGRATION FILES MANUALLY.**

**NEVER:**

- Create files under `supabase/migrations/` without `pnpm supabase:migration:new -- <name>`
- Provide SQL to paste into a hand-made migration path
- Use `pnpm supabase db diff -f <name>` (or `--file`) as the **sole** step to create a migration file (bypasses the stamped workflow)
- Edit **committed** migration files in place instead of adding a new migration
- Suggest bypassing the CLI workflow in [Database → Migrations](./docs/architecture/database.md#migrations)

**ALWAYS:**

- Apply changes on **local** DB first (Studio, psql, etc.)
- Run `pnpm supabase:migration:new -- <descriptive_name>` (prints **one line**: path to the new file), then `pnpm supabase db diff -o <that-path>` (and `pnpm supabase:migration:stamp` if the header was overwritten)
- Review the generated file
- Commit the CLI-generated file only

**Full details:** [Database → Migrations](./docs/architecture/database.md#migrations), [docs/architecture/tdd.md](./docs/architecture/tdd.md), [Golden Rules GR-015](./docs/standards/golden-rules.md#gr-015-cli-generated-migrations-only-critical---human-confirmation-required), [Anti-Patterns BAD-015](./docs/standards/anti-patterns.md#bad-015-manual-migration-files-critical---prohibited)

### Remote database and MCP (agents)

**Assume development and verification run against the local Supabase stack** (`pnpm supabase start`). `.env.local` should set `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` from **`pnpm exec supabase status`** (not a hosted project), and **must not** add `SUPABASE_SERVICE_ROLE_KEY` or `SUPABASE_PROJECT_REF` — the server resolves the local service role from the CLI when unset; see [docs/guides/supabase-setup.md](./docs/guides/supabase-setup.md).

**Agents MUST NOT:**

- Run Supabase CLI commands that **write** to a **linked remote** project (e.g. `supabase db push`, `supabase migration repair`, or ad-hoc SQL execution against remote from the CLI) without explicit human approval and a defined change-management process.
- Use **MCP servers** (or any tool) connected to a **remote** Supabase project to execute **DDL/DML** or destructive operations.
- Change `.env.local` to point at production or shared staging **for automation**; humans may do so locally at their own risk.

**Agents MAY:**

- Run `pnpm supabase db reset`, `pnpm supabase:types:local`, `pnpm supabase test db`, and app builds/tests against **local** config.
- Read remote documentation or schema for comparison **read-only**.

**Canonical doc:** [docs/guides/supabase-setup.md](./docs/guides/supabase-setup.md)

---

## Commit workflow (mandatory)

When the user asks to **commit**, **stage and commit**, open a **PR**, or finish work to merge, agents must follow this sequence **unless the user explicitly waives verification**.

### 1. Run the pipeline

From the monorepo root (`<repo>/`):

```bash
pnpm workflow
```

This runs **in order**: `pnpm lint` → `pnpm typecheck` → `pnpm build` → `pnpm format` (Prettier last). Root `pnpm build` is app-scoped: it builds deployable workspaces under `apps/`, not utility packages.

- If `pnpm format` changes files, run `pnpm lint` again (or re-run `pnpm workflow`) until checks stay green.
- Do not claim the branch is ready without a successful run.

**Script:** `workflow` in root `package.json`.

**What `pnpm workflow` does *not* run:** unit tests, coverage thresholds, `check:forbidden`, `check:security-smells`, or any database-backed suites (`test:integration`, `test:rls`, `test:sql`). Before opening a PR or merging, run **[pre-merge verification](#pre-merge-verification-local)** when you need full quality gates. CI runs `pnpm audit` at high severity as an **informational** step (`continue-on-error`) until transitive advisories are cleared; see root `package.json` script `audit:dependencies`.

### Pre-merge verification (local)

Use this when finishing work to **merge**, opening a **PR**, or when the user asks for checks beyond `pnpm workflow`. Command reference: [docs/architecture/testing.md](./docs/architecture/testing.md).

**Recommended quality pass** (no Docker required for this block):

```bash
pnpm lint
pnpm typecheck
pnpm check:forbidden
pnpm check:security-smells
pnpm test:coverage
```

**Supabase DB suites** (requires Docker + local Supabase):

```bash
pnpm test:integration:prepare   # supabase:start && supabase:db:reset
pnpm test:db                      # integration + RLS + SQL
```

If Supabase is already up and the DB matches migrations, you may skip `test:integration:prepare`—when in doubt, reset.

### 2. Review changes

Briefly inspect `git status` / `git diff` (or `--stat`) so the commit message reflects what actually changed.

### 3. Stage scope

- **Default:** `git add -A` (or equivalent) to stage **all** modified, new, and deleted files in the repo. Partial staging is **not** the default.
- **Exception:** Stage only a subset if the user **explicitly** asks to commit a specific path, package, or group of files.

### 4. Commit message

- **Language:** English.
- **Format:** [Conventional Commits](https://www.conventionalcommits.org/) (`feat`, `fix`, `chore`, `docs`, etc.) with a clear subject; use the body for multiple areas or non-obvious rationale.
- Summarize the full staged change set, not only the files the agent last edited.

### 5. Commit

Run `git commit` with the message from step 4 only after step 1 passes.

Before you **push**, open a **PR**, or tell the user the branch is **merge-ready**, complete [pre-merge verification](#pre-merge-verification-local) unless they explicitly waive database tests or extended checks.

---

## Documentation index

**This file is your entry point.** Detailed docs are linked below.

### Core documentation (repository root)

| Document | Purpose | When to read |
|----------|---------|----------------|
| **[docs/standards/repository-standards.md](./docs/standards/repository-standards.md)** | Canonical repo standards (operational contract) | Before any non-trivial change |
| **[docs/architecture/system.md](./docs/architecture/system.md)** | System architecture, package boundaries, module communication | Before starting any feature |
| **[docs/reference/stack.md](./docs/reference/stack.md)** | Pinned stack: Next 16, Tailwind 4, shadcn, Zod 4, TanStack, Supabase | Before upgrading dependencies or adding libraries |
| **[docs/architecture/backend.md](./docs/architecture/backend.md)** | Data layer standards (`@workspace/supabase-data`); infra note for `@workspace/supabase-infra` | When writing server actions, repos, or app data imports |
| **[docs/architecture/database.md](./docs/architecture/database.md)** | Database standards: RLS, Migrations, Functions, Policies | When creating/modifying database schema |
| **[docs/architecture/tdd.md](./docs/architecture/tdd.md)** | Strict TDD lifecycle (RED/GREEN/REFACTOR, migration-safe) | Before implementing features |
| **[docs/architecture/testing.md](./docs/architecture/testing.md)** | Vitest, coverage, integration/RLS commands | When writing or running tests |
| **[README.md](./README.md)** | Project overview, quick start, environment setup | First-time setup |
| **[GOLDEN_RULES.md](./docs/standards/golden-rules.md)** | Non-negotiable standards | Before every commit |
| **[ANTI_PATTERNS.md](./docs/standards/anti-patterns.md)** | Forbidden patterns | Before every commit |

### Secondary documentation (`docs/`)

| Document | Purpose |
|----------|---------|
| **[docs/guides/client-ui-data-sync.md](./docs/guides/client-ui-data-sync.md)** | Auto UI sync, optimistic updates, avoid full-page refresh | When wiring actions/API/hooks to the UI |
| **[docs/getting-started.md](./docs/getting-started.md)** | Quick navigation |
| **[apps/docs/README.md](./apps/docs/README.md)** | Cross-app product / business docs (Level 2 vs root `docs/`) |
| **[docs/reference/command-reference.md](./docs/reference/command-reference.md)** | All CLI commands |
| **[docs/architecture/overview.md](./docs/architecture/overview.md)** | Detailed system map |
| **[docs/guides/supabase-setup.md](./docs/guides/supabase-setup.md)** | Local-first Supabase, `.env.local`, forbidden remote writes for agents |
| **[docs/guides/seo.md](./docs/guides/seo.md)** | SEO defaults for `apps/example`: `metadataBase`, robots, sitemap, env vars |
| **[docs/checklists/seo-fork.md](./docs/checklists/seo-fork.md)** | Pre-launch SEO checklist before shipping a fork |
| **[apps/README.md](./apps/README.md)** | Applications directory |
| **[packages/README.md](./packages/README.md)** | Packages directory (`@workspace/*`) |

### SEO and discoverability (fork-time)

When renaming or shipping **`apps/example`** (or cloning its patterns into a new app), update **metadata**, **`NEXT_PUBLIC_SITE_URL`** (https for production builds), **`ROBOTS_ALLOW`**, **`NEXT_PUBLIC_DEFAULT_LOCALE`**, **`app/sitemap.ts`**, and **`public/og-default.png`**. Do not index auth or admin routes. Canonical guide: [docs/guides/seo.md](./docs/guides/seo.md); app notes: [apps/example/docs/seo.md](./apps/example/docs/seo.md).

---

## Project structure

```
<repo>/
├── apps/
│   ├── docs/         # Level 2: cross-app product / business (not template engineering)
│   └── example/
│       └── docs/     # Level 3: app-only domain docs (rename `example` when you add a real app)
├── packages/         # Shared packages (@workspace/*)
├── AGENTS.md
├── CLAUDE.md
├── GEMINI.md
└── docs/             # Level 1: template + repo standards (see docs/architecture/ for system, backend, DB, TDD, testing)
```

**Workspace data stack:** Apps use **`@workspace/supabase-data`** for queries, actions, and hooks, and **`@workspace/supabase-auth`** for session and claims. **`@workspace/supabase-infra`** is only Supabase **infra** (env, generated types, typed clients); it must not grow domain logic. **`@workspace/supabase-infra`** imports nothing from `supabase-auth` or `supabase-data`; `supabase-auth` depends on `supabase-infra`; `supabase-data` depends on `supabase-infra` and `supabase-auth`. See [docs/standards/repository-standards.md § Dependency matrix](./docs/standards/repository-standards.md#dependency-matrix-workspace).

---

## Critical rules (must follow)

### 1. `@workspace/ui` — immutable · `@workspace/brand` — shared product UI

**`packages/ui` is shadcn/ui and MUST stay read-only for human product edits:**

- **NEVER** modify shadcn components directly, add business logic inside them, or park “our” shared components there
- **ONLY** add/update primitives via: `pnpm dlx shadcn@latest add <component-name>`
- **Cursor agents:** `.cursor/rules/packages-ui-immutable.mdc` is always applied — do not use editor/agent tools to change files under `packages/ui/**` (use `@workspace/brand` or app code instead; humans run shadcn CLI for new primitives)

**Shared UI written by humans** (compositions, branded blocks reused across multiple apps) **MUST** live in **`packages/brand`** (`@workspace/brand`), importing from `@workspace/ui/components/*`.

**Correct — primitive consumption (app or brand package):**

```tsx
import { Button } from "@workspace/ui/components/button";

export function CustomButton(props) {
  return <Button {...props} className="custom-styles" />;
}
```

**Wrong:**

```tsx
// packages/ui/src/components/button.tsx — do not edit for product logic
```

**Supabase generated types:** `packages/supabase-infra/src/types/database.types.ts` is **CLI output only** (`pnpm supabase:types:local` / `pnpm supabase:types:linked`). **Do not** hand-edit it or use agent tools to change it; merge application-specific typing in `packages/supabase-infra/src/types/database.ts`. Cursor: `.cursor/rules/database-types-immutable.mdc`.

### 2. Zero-barrel policy (GR-001)

**NEVER** use barrel files (`index.ts` that re-exports). **ALWAYS** use subpath exports:

```typescript
// Correct
import { Button } from "@workspace/ui/components/button";
import { UserSchema } from "@workspace/types/schemas/user";

// Forbidden
import { Button } from "@workspace/ui";
import { UserSchema } from "@workspace/types";
```

### 3. No app-local data abstractions (BAD-003)

**NEVER** create `apps/*/lib/db/actions/*` or `apps/*/lib/repositories/*`.

**ALWAYS** import from shared packages near the feature (see [docs/architecture/backend.md](./docs/architecture/backend.md)):

```typescript
// Correct — import from shared data layer
import { getEntityAction } from "@workspace/supabase-data/actions/entities/get-entity";
import { useEntityList } from "@workspace/supabase-data/hooks/entities";

// Forbidden — app-local DB layer
import { createEntity } from "@/lib/db/actions/entities";
```

### 4. Parse at boundaries (GR-006)

**NEVER** use `as Type` on API responses or untrusted input. **ALWAYS** use Zod:

```typescript
const user = UserSchema.parse(response);
```

### 5. TypeScript strict mode (GR-004)

`strict` and `noUncheckedIndexedAccess` are enabled in shared `tsconfig` ([packages/typescript-config/base.json](./packages/typescript-config/base.json)). Additional flags (e.g. `exactOptionalPropertyTypes`) are documented in golden rules and may be enabled repo-wide in a future PR—see [docs/standards/repository-standards.md](./docs/standards/repository-standards.md#5-typescript-rules).

### 6. Tests (GR-007, GR-008, BAD-006)

Coverage thresholds, centralized test layout ([`tests/README.md`](./tests/README.md)), and no happy-path-only suites — [docs/architecture/testing.md](./docs/architecture/testing.md).

### 7. Auth on the server (GR-013)

Use `getClaims()` for server authorization; **never** `getSession()` on server paths. Client rules: [Backend → Authentication](./docs/architecture/backend.md#authentication).

### 8. Client UI sync — no manual refresh (GR-017)

After mutations (create/edit/delete), the UI must **update on its own** — cache invalidation / `setQueryData` / `revalidatePath` / `revalidateTag` as appropriate — **without** relying on a full page reload. Prefer **optimistic updates** and **local loading** (e.g. button `pending`) over global spinners. Details and checklist: **[docs/guides/client-ui-data-sync.md](./docs/guides/client-ui-data-sync.md)**.

### 9. Documentation — three levels (GR-019)

| Level | Path | Content |
|-------|------|---------|
| **1** | **`docs/`** (repo root) | Template engineering: agents, stack, TDD, migrations, golden rules — **no product domain** |
| **2** | **`apps/docs/`** | **Cross-app business / product** — glossary, flows, concepts shared by several apps |
| **3** | **`apps/<app>/docs/`** | **Single-app domain** — routes, features, runbooks scoped to one Next.js app |

**LLM rule of thumb:** business-in-general → **`apps/docs/`**; ultra-specific to one app → **`apps/<app>/docs/`**. See [GR-019](./docs/standards/golden-rules.md#gr-019-three-level-documentation-layout), [apps/docs/README.md](./apps/docs/README.md).

### 10. Auth invariants and trust boundaries

- **Server authz:** use `getClaims()`; do not use `getSession()` for server authorization decisions.
- **Session refresh:** root `proxy.ts` owns cookie/session refresh via `@workspace/supabase-auth/proxy/update-session`.
- **Boundary validation:** validate route/action inputs at the edge; internal functions receive typed validated data.
- **Sensitive auth routes:** call the abuse-protection hook before external auth work; keep the default hook vendor-neutral.

Short guide: [docs/guides/auth-invariants.md](./docs/guides/auth-invariants.md)

### 11. Security invariants (short mirror for tools)

Non-negotiables are enforced by `pnpm check:forbidden` and `pnpm check:security-smells`. Cursor loads [`.cursor/rules/security-invariants.mdc`](./.cursor/rules/security-invariants.mdc) as a compact checklist; canonical detail remains this file and linked guides.

---

## Development commands

```bash
pnpm install

# All apps
pnpm dev

# One app
pnpm --filter example dev

pnpm build
pnpm lint
pnpm typecheck
pnpm test
pnpm check:forbidden   # forbidden paths + packages/ui Git diff (GR-001) + server getSession guard
```

See **[docs/reference/command-reference.md](./docs/reference/command-reference.md)** for the full list.

---

## Environment variables

Single **`.env.local`** at the repository root (apps inherit). Copy from **`.env.example`** when present; inline comments there describe layout, rules, and links to deeper guides.

---

## Decision flowcharts

### Where do I put this code?

```
Is it a shared shadcn primitive (new base component)?
├─ YES → packages/ui via shadcn CLI ONLY
└─ NO → Is it shared product UI (multi-app, hand-written compositions)?
         ├─ YES → packages/brand (@workspace/brand)
         └─ NO → Is it data / persistence / server actions?
                  ├─ YES → `@workspace/supabase-data` (see [docs/architecture/backend.md](./docs/architecture/backend.md)); `@workspace/supabase-infra` only for Supabase infra (types/env/clients), not domain logic
                  └─ NO → Is it app-specific UI?
                           ├─ YES → apps/[app]/_components / routes
                           └─ NO → Zod/schema? → packages/types or module DTOs
```

### Should I create a new server action?

```
Need to expose data/mutation to clients?
├─ NO → Keep internal (repository layer)
└─ YES → Already in shared package?
         ├─ YES → Import and use
         └─ NO → Add in shared package per [Backend](./docs/architecture/backend.md) → Server Actions
```

### Which auth method?

```
SERVER
├─ Need userId / claims? → getClaims() (primary)
├─ Need Auth DB consistency? → getUser() (fallback)
└─ For UI state on server? → NEVER getSession()

CLIENT
├─ Reactive auth? → AuthProvider + useAuth()
├─ One-off? → getClientClaims()
└─ UI/session? → getSession() acceptable on client
```

See **[Backend → Authentication](./docs/architecture/backend.md#authentication)** for full detail.

### Change routing map

| Change type | Home |
|-------------|------|
| shadcn primitive / base UI | `packages/ui` via shadcn CLI only |
| Shared product UI | `packages/brand` |
| Auth/session/proxy | `packages/supabase-auth` |
| Data access / repositories / server actions | `packages/supabase-data` |
| Supabase env / typed clients / generated DB types | `packages/supabase-infra` |
| DB schema / RLS / pgTAP | `supabase/` |
| Repo rules / automation / template docs | root `docs/`, `AGENTS.md`, `scripts/ci/` |
| App-specific presentation | `apps/<app>/app`, `apps/<app>/components` |

---

## Documentation hierarchy

```
ROOT
├── README.md           # Humans — onboarding
├── AGENTS.md           # AI entry (this file)
├── CLAUDE.md / GEMINI.md  # Pointers → AGENTS.md + docs/
├── apps/
│   ├── docs/             # Level 2: cross-app product / business
│   └── <app>/docs/       # Level 3: single-app domain
└── docs/
    ├── README.md         # docs index
    ├── getting-started.md
    ├── standards/        # repository-standards, golden-rules, anti-patterns
    ├── reference/        # stack, command-reference
    ├── guides/           # supabase-setup, migration-workflow, client-ui-data-sync, …
    └── architecture/     # system, backend, database, TDD, testing, ADRs
```

---

## Key principles

1. **Separation of concerns:** UI in apps; **data access via `@workspace/supabase-data`** per [docs/architecture/backend.md](./docs/architecture/backend.md); **`@workspace/supabase-infra`** is Supabase infra (types/env/clients), not the product data API
2. **Immutable UI package:** shadcn components are dependencies, not ad-hoc product code — never hand-edit `packages/ui` for product features
3. **Shared product UI:** hand-written cross-app components go in **`@workspace/brand`**, not in `packages/ui`
4. **Composition:** extend via wrappers, not edits inside `packages/ui` sources
5. **Documentation-driven:** [System layers](./docs/architecture/system.md) first for features; [TDD](./docs/architecture/tdd.md) + [Testing](./docs/architecture/testing.md) for process and tests
6. **Migration safety:** CLI-generated migrations only; [TDD](./docs/architecture/tdd.md) defines order with schema

---

## Quick reference

| Task | Documentation |
|------|----------------|
| Architecture | [docs/architecture/system.md](./docs/architecture/system.md) |
| Shared product UI (multi-app) | [packages/brand/README.md](./packages/brand/README.md) |
| Data layer / server actions | [docs/architecture/backend.md](./docs/architecture/backend.md) (apps use `@workspace/supabase-data`; `@workspace/supabase-infra` = Supabase infra only) |
| TDD / schema order | [docs/architecture/tdd.md](./docs/architecture/tdd.md) |
| Tests / commands | [docs/architecture/testing.md](./docs/architecture/testing.md) |
| Migrations / RLS | [docs/architecture/database.md](./docs/architecture/database.md) |
| New UI component | This file — Critical rule #1 |
| Imports | [Backend → Import Guidelines](./docs/architecture/backend.md#import-guidelines) |
| Errors | [Backend → Error Handling](./docs/architecture/backend.md#error-handling) |
| Auth | [Backend → Authentication](./docs/architecture/backend.md#authentication) |
| Pinned stack (versions) | [docs/reference/stack.md](./docs/reference/stack.md) |
| Docs: root vs `apps/docs` vs `apps/<app>/docs` | [GR-019](./docs/standards/golden-rules.md#gr-019-three-level-documentation-layout), [apps/docs/README.md](./apps/docs/README.md) |
| Daily commands | [docs/reference/command-reference.md](./docs/reference/command-reference.md) |
| Pre-merge checks | [Commit workflow → Pre-merge](#pre-merge-verification-local), [docs/architecture/testing.md](./docs/architecture/testing.md) |
| Test trust (coverage vs DB) | [Test trust boundaries](#test-trust-boundaries-agents) |
| Rules | [docs/standards/golden-rules.md](./docs/standards/golden-rules.md) |
| Anti-patterns | [docs/standards/anti-patterns.md](./docs/standards/anti-patterns.md) |

---

**Last updated:** 2026-03-28 (repository standards: [docs/standards/repository-standards.md](./docs/standards/repository-standards.md))
