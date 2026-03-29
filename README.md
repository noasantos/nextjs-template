# Turborepo + Next.js + Supabase template

Monorepo starter: **Next.js 16**, **React 19**, **Tailwind CSS v4**, **shadcn/ui** (in `packages/ui`), **Zod v4**, **TanStack** (Query / Table / Form as wired per app), **Supabase** (local-first), **pnpm** + **Turborepo**. Canonical version list: **[docs/reference/stack.md](./docs/reference/stack.md)**.

## Local development (Supabase)

Backend auth and data run against a **local Supabase** stack by default. Read this before you run the apps.

### What you must install

1. **Docker** — **Docker Desktop** (macOS/Windows) or Docker Engine + Compose (Linux). The Supabase CLI runs Postgres, Auth, Storage, etc. in containers. **Docker must be running** before you start the stack.  
   - Install: [Get Docker](https://docs.docker.com/get-docker/) · [Docker Desktop](https://www.docker.com/products/docker-desktop/)

2. **Supabase CLI** — Required to run `supabase start`, migrations, and codegen. This repo already lists the CLI as a dev dependency; use it via **`pnpm`** from the repository root (e.g. `pnpm supabase start`).  
   - Official install options (Homebrew, Scoop, npm, etc.): [Supabase CLI — getting started](https://supabase.com/docs/guides/cli/getting-started)  
   - How local dev works (images, ports, Studio): [Local development with Supabase CLI](https://supabase.com/docs/guides/cli/local-development)  
   - Command reference: [CLI reference](https://supabase.com/docs/reference/cli/introduction)

3. **Node.js** and **pnpm** — Install dependencies with `pnpm install` at the monorepo root.

### Quick start (after Docker is running)

```bash
pnpm install
pnpm supabase start          # first run may take a while (image download)
cp .env.example .env.local   # then fill NEXT_PUBLIC_* from `pnpm exec supabase status`
pnpm supabase db reset       # migrations + seed (when you need a clean DB)
pnpm dev                     # or apps individually, e.g. pnpm --filter example dev
```

Full workflow, `.env.local` rules, and safety notes: **[docs/guides/supabase-setup.md](./docs/guides/supabase-setup.md)**.

---

## Standards and TDD

- **[docs/README.md](./docs/README.md)** — index of all Level 1 docs; **[docs/getting-started.md](./docs/getting-started.md)** — quick navigation  
- **[docs/reference/stack.md](./docs/reference/stack.md)** — pinned technology stack (Next 16, Zod 4, Tailwind 4, TanStack, Supabase, …)  
- **[docs/standards/repository-standards.md](./docs/standards/repository-standards.md)** — canonical repo contract (agents + contributors)  
- [docs/architecture/system.md](./docs/architecture/system.md) — system layers and package boundaries  
- [docs/architecture/tdd.md](./docs/architecture/tdd.md) — strict test-driven development (migration-safe)  
- [docs/architecture/testing.md](./docs/architecture/testing.md) — Vitest, coverage, integration/RLS; `pnpm test:all` runs full tests (coverage + DB suites)  
- [AGENTS.md](./AGENTS.md) — AI/agent entry (links all rules; local Supabase only for agents)  
- [docs/guides/supabase-setup.md](./docs/guides/supabase-setup.md) — Supabase prerequisites + env + migrations

## Adding components

Shared primitives live in **`packages/ui`**. Add or update them **only** via the shadcn CLI (do not hand-edit for product features):

```bash
pnpm dlx shadcn@latest add button -c packages/ui
```

This installs into `packages/ui/src/components` (see [packages/ui/README.md](./packages/ui/README.md)).

## Using components

To use the components in your app, import them from the `ui` package.

```tsx
import { Button } from "@workspace/ui/components/button";
```

**Do not hand-edit `packages/ui`.** Shared product UI for multiple apps lives in **`@workspace/brand`** (`packages/brand`). See [packages/ui/README.md](./packages/ui/README.md) and [packages/brand/README.md](./packages/brand/README.md).

The **`example`** app (`pnpm --filter example dev`, default port **3000** in this template) is a shell for marketing, auth, and admin routes. See [apps/example/README.md](./apps/example/README.md). Post-login behaviour lives in `@workspace/supabase-auth` (e.g. `app-destination.ts`) — adjust when you fork.
