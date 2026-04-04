# Getting started

Welcome. This is a **pnpm + Turborepo** monorepo with **Next.js 16**,
**Supabase**, **Tailwind v4**, **shadcn**, **Zod v4**, and **TanStack** (see
**[reference/stack.md](reference/stack.md)**). The template ships one app:
**`example`**. Canonical rules:
**[standards/repository-standards.md](standards/repository-standards.md)** and
**[AGENTS.md](../AGENTS.md)**.

## Quick links

| Topic                 | Document                                                               |
| --------------------- | ---------------------------------------------------------------------- |
| Pinned stack          | [reference/stack.md](reference/stack.md)                               |
| Repo contract         | [standards/repository-standards.md](standards/repository-standards.md) |
| Architecture handbook | [architecture/README.md](architecture/README.md)                       |
| Supabase local        | [guides/supabase-setup.md](guides/supabase-setup.md)                   |
| Commands              | [reference/command-reference.md](reference/command-reference.md)       |

## Apps

| App         | Role                                       | README                                                 |
| ----------- | ------------------------------------------ | ------------------------------------------------------ |
| **example** | Template Next.js surface (marketing, auth) | [../apps/example/README.md](../apps/example/README.md) |

## Common commands

```bash
pnpm install
pnpm dev
pnpm --filter example dev
```

See **[reference/command-reference.md](reference/command-reference.md)** for the
full list.
