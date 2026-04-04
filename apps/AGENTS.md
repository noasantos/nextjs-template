# Applications (`apps/`) — agents

**Audience:** agents / LLM. Human overview: [`README.md`](./README.md).

## Layout

| Path       | Dev port      | Role                                                                    |
| ---------- | ------------- | ----------------------------------------------------------------------- |
| `example/` | 3000          | Template Next.js app (rename when shipping a real product)              |
| `web/`     | (see package) | Additional surface when you add one                                     |
| `docs/`    | —             | [Level 2 product docs](./docs/AGENTS.md) — cross-app business / product |

Per-app domain docs: `apps/<app>/docs/` (Level 3). Repo / template standards:
monorepo root [`docs/`](../docs/standards/golden-rules.md).

**Server Actions:** do **not** live here — no `app/**` file with `"use server"`,
no `apps/<app>/actions/`. Put actions in
[`packages/supabase-data/src/actions/`](../packages/supabase-data/src/actions/)
and call them from route/handler code.

**Naming:** primary signal is **folders** (`app/`, `_hooks/`, `_providers/`,
kebab-case). **Do not** use `*.hook.*`, `*.component.*`, or `*.provider.*` in
app filenames — those suffixes are **packages-only** (see
[`docs/standards/package-file-suffixes.md`](../docs/standards/package-file-suffixes.md)).
Framework files (`page.tsx`, `layout.tsx`, `route.ts`, …) keep Next defaults.

## Before production

Replace “Example App” copy, set `NEXT_PUBLIC_SITE_URL`, enable
`ROBOTS_ALLOW=true` only where you want indexing —
[`docs/guides/seo.md`](../docs/guides/seo.md),
[`docs/checklists/seo-fork.md`](../docs/checklists/seo-fork.md).

See [`docs/architecture/overview.md`](../docs/architecture/overview.md).
