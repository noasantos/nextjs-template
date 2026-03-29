# Architecture Overview

**Last Updated:** 2026-03-28

This document is a **high-level map** of the Turborepo template: apps, shared packages, and how they relate. Rename `apps/example` and adjust ports when you fork.

## System Map

```
┌─────────────────────────────────────────────────────────────────┐
│              Turborepo + pnpm workspace template                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Apps (Next.js + TypeScript)                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  example │ dev port from app (default 3000) │ marketing, auth, admin │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Packages (shared)                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  @workspace/supabase-auth   │ session, claims, guards       │  │
│  │  @workspace/supabase-infra  │ env, generated types, clients │  │
│  │  @workspace/supabase-data   │ repositories, actions, hooks│  │
│  │  @workspace/forms           │ shared form helpers           │  │
│  │  @workspace/ui              │ shadcn primitives (CLI only)  │  │
│  │  @workspace/brand           │ shared product UI             │  │
│  │  @workspace/test-utils      │ Supabase test clients, env    │  │
│  │  @workspace/vitest-config   │ Vitest presets                │  │
│  └──────────────────────────────────────────────────────────┘  │
│  tests/ @workspace/tests — integration + RLS Vitest runner       │
│                                                                  │
│  Infrastructure                                                 │
│  │  pnpm · Turborepo · Supabase (local CLI stack)              │  │
└─────────────────────────────────────────────────────────────────┘
```

## App details

### `example` (default dev port 3000)

**Purpose:** Template “main” app: public routes, Supabase auth routes, and an admin area. Rename the folder and `package.json` name for your product.

**See:** [`apps/example/README.md`](../../apps/example/README.md)

---

## Package details

### `@workspace/ui`

shadcn/ui **primitives** only — add components with the shadcn CLI; do not hand-edit for product features. See [`packages/ui/README.md`](../../packages/ui/README.md).

---

### `@workspace/brand`

Shared **product** UI used by more than one app (built on `@workspace/ui`). See [`packages/brand/README.md`](../../packages/brand/README.md).

---

### `@workspace/forms`

Shared form helpers (TanStack Form + Zod patterns as adopted in the repo).

---

### `@workspace/supabase-auth`

Authentication utilities, session/claims helpers, and routing helpers such as [`app-destination.ts`](../../packages/supabase-auth/src/shared/app-destination.ts). Depends on `@workspace/supabase-infra` only.

---

### `@workspace/supabase-infra`

Supabase env wiring, generated `Database` types, typed clients. **No** domain tables or business rules — infra only.

---

### `@workspace/supabase-data`

Repositories, server actions, hooks — the **only** place for `.from()` / RPC usage against Postgres in app code paths. See [`backend.md`](./backend.md).

---

### `@workspace/eslint-config` · `@workspace/typescript-config` · `@workspace/vitest-config`

Shared tooling configuration for apps and packages.

---

## Authentication (conceptual)

```
User → public pages → Supabase Auth (hosted or local) → callback/session
     → post-login destination from JWT/claims + app-destination helpers
```

Implement **role and URL rules** in code and document them in your app README or a new ADR.

---

## Development commands

```bash
pnpm dev
pnpm --filter example dev
pnpm build
pnpm lint
pnpm typecheck
pnpm test
```

---

## Key architectural decisions

### ADR-001: Monorepo structure with zero-barrel policy

- pnpm workspaces + Turborepo  
- Explicit subpath exports (no barrel files)

See [001-monorepo-structure.md](./decisions/001-monorepo-structure.md).

---

## See also

- [system.md](./system.md) — layers and boundaries  
- [apps/README.md](../../apps/README.md) — applications directory  
- [backend.md](./backend.md) — data layer
