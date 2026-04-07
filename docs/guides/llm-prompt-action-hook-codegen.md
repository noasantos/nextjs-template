# LLM-to-LLM prompt: codegen for Server Actions + TanStack Query hooks

Copy the block below into a downstream coding agent. It assumes the repo is this
template (Fluri or fork) with `config/domain-map.json`,
`config/repository-plan.json`, and `pnpm codegen:backend` already producing
repositories.

---

## Prompt (English, paste below this line)

You are implementing **automated codegen** (and optional **semantic
completion**) for:

1. **Server Actions** under
   `packages/supabase-data/src/actions/<module>/<name>.codegen.ts`
2. **TanStack Query hooks** under
   `packages/supabase-data/src/hooks/<domain>/use-<entity>-query|mutation.hook.codegen.ts`
3. **Query key factories** in
   `packages/supabase-data/src/hooks/<domain>/query-keys.codegen.ts`

### Non-negotiable architecture

- **Repositories** are the only place for `supabase.from(...)`. Actions call
  repositories; hooks call actions inside `queryFn` / `mutationFn` only.
- **Server Actions** use `"use server"`, `requireAuth()` from
  `@workspace/supabase-data/lib/auth/require-auth`, Zod input validation, and
  structured logging via `logServerEvent` from `@workspace/logging/server` on
  **both success and failure** (observability, not only errors). Include
  `component`, `eventFamily`, `eventName`, `outcome`, `durationMs`, `actorId`
  when known, and **rich `metadata`** (entity ids, operation, safe filter
  summaries — never secrets or full PII).
- **Hooks** use `"use client"`, `useQuery` / `useMutation` from
  `@tanstack/react-query`, import query keys only from
  **`query-keys.codegen.ts`** for that domain (no scattered string literals).
  **Do not** use `console.log` in hooks.
- **Package exports**: every new action path and hook path needs an explicit
  entry in `packages/supabase-data/package.json` → `exports` (sorted), matching
  existing style.
- **Naming convention**: All generated files must have `.codegen.` in the
  filename (e.g., `*.codegen.ts`, `*.codegen.test.ts`) for easy cleanup.

### Mechanical templates (reuse recursively)

- **Action scaffold:** mirror `scripts/actions/new-action.ts` output (file
  layout, logging placeholders, Zod, `serializeResult` / `ActionResult` if
  present in repo; if those libs are missing, align with whatever boundary types
  the repo actually ships — do not invent unused imports).
- **Hook scaffold:** mirror `scripts/hooks/new-hook.ts` output
  (`query-keys.codegen.ts` factory pattern,
  `use-<entity>-query|mutation.hook.codegen.ts`).
- **CLI parity:** document that humans/LLMs can run
  `pnpm action:new -- <module> <name>` and
  `pnpm hook:new -- <domain> <entity> query|mutation` before codegen fills
  bodies.

### Codegen pipeline (suggested phases)

**Phase A — Deterministic (no LLM):**

- Parse `config/repository-plan.json` + `config/domain-map.json` +
  `packages/supabase-infra/src/types/database.types.ts`.
- For each codegen table, derive `(domainId, table, methods)` and emit **action
  stubs** only for operations that need an app-facing API (start with `list` +
  `findById` for reads; `insert`/`update`/`delete` for writes per plan). File
  naming: kebab-case with `.codegen.` extension, one primary action per
  repository method group if that keeps imports predictable.
- Emit **hook stubs** paired to actions:
  `use-<table-kebab>-query.hook.codegen.ts` for read actions,
  `use-<table-kebab>-mutation.hook.codegen.ts` for mutations; extend
  `query-keys.codegen.ts` with typed factories
  (`<domainCamel>QueryKeys.<entityCamel>()` / `...List(filters)`).

**Phase B — Semantic (LLM, non-deterministic):**

- For each action: choose **minimal Zod input** from `Insert`/`Update` Row types
  and plan methods; add **defense-in-depth** checks (e.g. tenant/psychologist
  scoping) if types or FKs imply multi-tenant boundaries.
- For each mutation hook: decide **`onMutate` optimistic update** vs simple
  `invalidateQueries`; list **which query keys** to invalidate (precise, not
  only `all`).
- For **cross-table** mutations, document invalidation sets in hook comments or
  a small `invalidation-map.json` if you introduce one.

**Phase C — Validation**

- Run `pnpm codegen:repository-plan:validate -- --strict` (if plan changed),
  `pnpm typecheck`, `pnpm lint` (**Oxlint** only). Verify **Rule 4** manually or
  with tests: no direct `myAction()` in `"use client"` outside `queryFn` /
  `mutationFn`, JSX `action={...}`, or `useActionState` with an action
  **reference**. **Do not** add ESLint; this repository uses Oxlint as the sole
  linter.

### Deliverables

1. A **script or Turbo task** (e.g. `pnpm codegen:actions-hooks`) that runs
   Phase A and writes files idempotently (use `*.codegen.*` filenames; backend
   stubs use `// codegen:backend —` on line 1).
2. **Documentation snippet** in `docs/architecture/data-access-pattern.md` if
   behaviour differs from the human-authored baseline.
3. **CHANGELOG** `[Unreleased]` entries under **Added** / **Changed** for new
   scripts, deps, or doc.

### Out of scope

- Changing `packages/ui/**` (immutable for agents).
- Hand-editing `database.types.ts` (regenerate via `pnpm supabase:types:local`).
- **ESLint** or any second linter — use **Oxlint** (`pnpm lint`) only.

End of prompt.

---

## Human note

The canonical prose spec for apps lives in
[`docs/architecture/data-access-pattern.md`](../architecture/data-access-pattern.md).
