# Supabase Setup

This repository uses a single root `supabase/` project managed by the Supabase
CLI.

## Prerequisites (local stack)

Before `pnpm supabase start` works, you need:

| Requirement            | Why                                                                                                                                                                                                                                                                                                                                  | Documentation                                                                                                                                       |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Docker**             | The CLI runs Postgres, Auth, Storage, etc. in containers. Install **Docker Desktop** (macOS/Windows) or **Docker Engine** + Compose (Linux). **Start Docker** before the CLI.                                                                                                                                                        | [Docker: Get Docker](https://docs.docker.com/get-docker/) · [Docker Desktop](https://www.docker.com/products/docker-desktop/)                       |
| **Supabase CLI**       | Talks to Docker and applies `supabase/migrations/*`. This repo already depends on it — use **`pnpm`** / **`pnpm exec`** from the repo root (see `package.json` scripts). You can also install globally: [Supabase CLI install](https://supabase.com/docs/guides/cli/getting-started) (Homebrew, Scoop, npm as dev dependency, etc.). | [CLI getting started](https://supabase.com/docs/guides/cli/getting-started) · [CLI reference](https://supabase.com/docs/reference/cli/introduction) |
| **Node.js** + **pnpm** | Match the versions your team uses; install deps with `pnpm install` at the monorepo root.                                                                                                                                                                                                                                            | [pnpm installation](https://pnpm.io/installation)                                                                                                   |

**Official overview of local development:**
[Local development with Supabase CLI](https://supabase.com/docs/guides/cli/local-development)
— first start can take several minutes while images download.

**Useful checks:** `pnpm supabase status` (URLs and keys) · `pnpm supabase stop`
when you are done (data is kept by default).

## Package boundaries

- `@workspace/supabase-auth`: SSR/browser auth clients, session helpers, auth
  flows, and shared `proxy` logic.
- `@workspace/supabase-infra`: generated database types, Supabase env access,
  and privileged server-only clients.
- `@workspace/supabase-data`: repository-based data access for app-facing tables
  such as `profiles` and `user_roles`.
- `apps/*`: UI composition only. Apps should import from the auth/data packages
  (or infra for rare tooling), not construct raw Supabase clients.

## Default development workflow (local Supabase)

**Use the local stack** so schema, RLS, and seeds match `supabase/migrations/`
and `supabase/seed.sql` (single file; sections inside are commented — see
`[db.seed].sql_paths` in `supabase/config.toml`) without touching any hosted
project.

1. `pnpm supabase start` (once per machine/session).
2. Copy `.env.example` → `.env.local` if you do not have it yet.
3. Fill **local** values from `pnpm exec supabase status`:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL` (typically
     `http://127.0.0.1:54321`)
   - **Publishable** → `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
4. **Do not** put `SUPABASE_SERVICE_ROLE_KEY` (or `SUPABASE_PROJECT_REF`) in
   `.env.local` / `.env.example`. The server resolves the local service-role JWT
   from `pnpm exec supabase status -o env` when that variable is unset in
   non-production. Production and preview hosts must inject
   `SUPABASE_SERVICE_ROLE_KEY` only via the platform secret store (e.g. Vercel),
   never in committed files.
5. Set `NEXT_PUBLIC_AUTH_APP_URL` in `.env.local` to your primary app origin
   (same host/port as the Next.js app that serves `/sign-in`, `/callback`,
   etc.).
6. Set `NEXT_PUBLIC_SITE_URL` to the **canonical public origin** for metadata
   and sitemap (often the same value as `NEXT_PUBLIC_AUTH_APP_URL` for
   single-app setups). Production `next build` requires **https** and a
   non-local hostname—see [seo.md](./seo.md) and
   [preview-environments.md](./preview-environments.md).
7. Keep `ROBOTS_ALLOW` **false** or unset locally and on preview; set
   **`ROBOTS_ALLOW=true`** only on the production deployment you want indexed.
8. Apply migrations and seed: `pnpm supabase db reset` (or let migrations apply
   on first start).
9. Regenerate types after schema changes: `pnpm supabase:types:local`.
10. Start apps: `pnpm dev` / `pnpm --filter example dev`, etc.

Studio local: URL shown in `supabase status` (usually `http://127.0.0.1:54323`).

## Hosted / remote Supabase (optional, human-only)

Pointing `.env.local` at a **remote** project is only for manual testing when
you explicitly need hosted behaviour. **Do not** use remote URLs or keys in
**agent/automated** flows, and **do not** run CLI commands that **write** to the
remote database from this repo’s automation (see [AGENTS.md](../AGENTS.md) §
Remote database and MCP).

If you must link the CLI to a non-production project:
`pnpm supabase link --project-ref <ref>`, then `pnpm supabase:db:pull` /
`pnpm supabase:types:linked` as appropriate — **never** `db push` or ad-hoc SQL
against production from an agent session.

## Migrations

Do not create files under `supabase/migrations/` by hand. Use the stamped
workflow:

1. Make schema changes against the **local** Supabase database.
2. `pnpm supabase:migration:new -- <descriptive_name>` (creates the file, stamps
   it; **stdout** is one line — the path to use below).
3. `pnpm supabase db diff -o <that path>` (exact path from step 2). Run
   `pnpm supabase:migration:stamp -- <that path>` if the diff overwrote the
   header.
4. Review the migration file.
5. Rebuild the local database with `pnpm supabase:db:reset` when you need a
   clean apply.
6. Regenerate types with `pnpm supabase:types:local`.

Details: [docs/guides/migration-workflow.md](./migration-workflow.md),
[DATABASE.md](../architecture/database.md#migrations).

## Safety notes

- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` is the browser-safe Supabase
  publishable (anon) key.
- `NEXT_PUBLIC_AUTH_ALLOWED_REDIRECT_ORIGINS` lists **extra** origins allowed
  for `redirect_to` (comma-separated). The app origin from
  `NEXT_PUBLIC_AUTH_APP_URL` is always allowed.
- The app behind `NEXT_PUBLIC_AUTH_APP_URL` serves `/sign-in`, `/callback`,
  `/auth/confirm`, `/continue`, `/logout`, `/forgot-password`,
  `/reset-password`, `/magic-link`, `/mfa`, and public `/` in this template.
- `NEXT_PUBLIC_AUTH_COOKIE_DOMAIN` should stay empty in local development and be
  set only for shared parent-domain staging/production deployments.
- **Service role:** never add `SUPABASE_SERVICE_ROLE_KEY` to tracked env
  templates or share it in chat/docs. Local dev uses CLI resolution
  (`packages/supabase-infra/src/env/resolve-service-role-key.ts`); hosted
  deploys set it in the provider’s secrets UI only.
- Use `getClaims()` for server authorization decisions. Do not trust
  `getSession()` for authorization.
