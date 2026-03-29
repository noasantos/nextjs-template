# Documentation index

Index of **repository-level** documentation in this repository. **AI entry:** [AGENTS.md](../AGENTS.md). **Human contract:** [standards/repository-standards.md](./standards/repository-standards.md).

**Scope (Level 1):** This **`docs/`** tree is **only** for **template and engineering** standards. **Cross-app product / business** docs belong under **`apps/docs/`**; **single-app** domain docs under **`apps/<app>/docs/`** ([GR-019](./standards/golden-rules.md#gr-019-three-level-documentation-layout)).

---

## Layout (by folder)

| Folder | Contents |
|--------|----------|
| **[standards/](./standards/)** | Repo contract, golden rules, anti-patterns |
| **[reference/](./reference/)** | Pinned stack versions, CLI / pnpm command reference |
| **[guides/](./guides/)** | Supabase local setup, migrations workflow, UI sync, observability, SEO, fork notes |
| **[checklists/](./checklists/)** | Short pre-launch checklists (e.g. SEO fork) |
| **[architecture/](./architecture/)** | System/backend/database/TDD/testing handbooks, overview, ADRs |

**Naming:** kebab-case `.md` files, except `README.md` index files.

---

## Core entrypoints

| Document | Purpose | When to read |
|----------|---------|--------------|
| **[standards/repository-standards.md](./standards/repository-standards.md)** | Canonical repo contract (agents + contributors) | Before any non-trivial change |
| **[architecture/README.md](./architecture/README.md)** | Hub: system, backend, database, TDD, testing | Before features, schema, or tests |
| **[reference/stack.md](./reference/stack.md)** | Pinned versions: Next 16, Zod 4, Tailwind 4, TanStack, Supabase | Upgrades and new dependencies |
| **[README.md](../README.md)** | Quick start, env setup | First-time setup |
| **[AGENTS.md](../AGENTS.md)** | AI agent instructions | Agents (and humans tuning workflows) |

---

## Getting started

- **[getting-started.md](./getting-started.md)** — First navigation (stack, standards, architecture, Supabase)
- **[reference/command-reference.md](./reference/command-reference.md)** — Commands and workflows

---

## Standards

- **[Golden rules](./standards/golden-rules.md)** — Non-negotiable standards (GR-\*)
- **[Anti-patterns](./standards/anti-patterns.md)** — Forbidden patterns (BAD-\*)

---

## Architecture

- **[Architecture handbook](./architecture/README.md)** — System, backend, database, TDD, testing
- **[Architecture overview](./architecture/overview.md)** — High-level system map
- **[ADR-001 — Monorepo structure](./architecture/decisions/001-monorepo-structure.md)** — Zero-barrel policy

Further ADRs belong in `docs/architecture/decisions/` as you lock in product decisions.

---

## Apps and packages

- **[Apps](../apps/README.md)** — Applications under `apps/`
- **[Packages](../packages/README.md)** — `@workspace/*` packages

### Product documentation (under `apps/`)

- **[apps/docs/README.md](../apps/docs/README.md)** — **Level 2:** cross-app business / product (not template standards)
- **`apps/<app>/docs/`** — **Level 3:** single-app domain (each app has its own `README.md`)

---

## Guides

- **[Supabase (local)](./guides/supabase-setup.md)** — Stack, env, agent safety
- **[Web security baseline](./guides/web-security-baseline.md)** — Template-safe headers and CSP rollout
- **[Auth invariants](./guides/auth-invariants.md)** — Server auth rules, boundary validation, abuse protection
- **[Migration workflow](./guides/migration-workflow.md)** — CLI migrations order
- **[Client UI data sync](./guides/client-ui-data-sync.md)** — Cache invalidation, optimistic UI
- **[Observability](./guides/observability-architecture.md)** — Logging contracts (if used)
- **[Repository hygiene](./guides/repository-hygiene.md)** — Dependabot, dependency review, CodeQL, secrets
- **[Turbo caching](./guides/turbo-caching.md)** — Task caching and non-cacheable paths
- **[Bundle observability](./guides/bundle-observability.md)** — Client bundle summary command
- **[Supabase performance](./guides/supabase-performance.md)** — Query, RLS, and index guardrails
- **[Template fork notes](./guides/template-fork-notes.md)** — Rename/delete when forking the template
- **[SEO & discoverability](./guides/seo.md)** — metadataBase, robots, sitemap, canonical, fork patterns
- **[Preview / staging](./guides/preview-environments.md)** — `ROBOTS_ALLOW`, Vercel preview URLs, Search Console
- **[i18n & `lang`](./guides/i18n-lang.md)** — default locale, hreflang, content parity
- **[Structured data (JSON-LD)](./guides/structured-data.md)** — Organization, Article, Product, Breadcrumbs
- **[SEO fork checklist](./checklists/seo-fork.md)** — Quick reference before production deploy

---

## Documentation hierarchy

```
ROOT
├── README.md
├── AGENTS.md
├── CLAUDE.md
├── GEMINI.md
├── apps/
│   ├── docs/               # Level 2: cross-app business / product
│   └── <app>/
│       └── docs/           # Level 3: single-app domain (see GR-019)
└── docs/
    ├── README.md           # This index
    ├── getting-started.md
    ├── standards/
    │   ├── repository-standards.md
    │   ├── golden-rules.md
    │   └── anti-patterns.md
    ├── reference/
    │   ├── stack.md
    │   └── command-reference.md
    ├── guides/
    │   ├── supabase-setup.md
    │   ├── migration-workflow.md
    │   ├── client-ui-data-sync.md
    │   ├── observability-architecture.md
    │   ├── seo.md
    │   ├── preview-environments.md
    │   ├── i18n-lang.md
    │   ├── structured-data.md
    │   └── template-fork-notes.md
    ├── checklists/
    │   └── seo-fork.md
    └── architecture/
        ├── README.md
        ├── system.md
        ├── backend.md
        ├── database.md
        ├── tdd.md
        ├── testing.md
        ├── overview.md
        └── decisions/
```

---

## Quick navigation

### Developers

1. [Root README](../README.md)
2. [Getting started](./getting-started.md)
3. [Command reference](./reference/command-reference.md)
4. [Golden rules](./standards/golden-rules.md)
5. [Architecture overview](./architecture/overview.md)

### AI agents

1. [standards/repository-standards.md](./standards/repository-standards.md)
2. [AGENTS.md](../AGENTS.md)
3. [architecture/tdd.md](./architecture/tdd.md)
4. [architecture/system.md](./architecture/system.md)
5. [Golden rules](./standards/golden-rules.md) · [Anti-patterns](./standards/anti-patterns.md)

---

## Updating documentation

1. Code changes → update the relevant standard or app README
2. New app or package → add to [apps/README.md](../apps/README.md) or [packages/README.md](../packages/README.md)
3. Architecture decision → add an ADR under `docs/architecture/decisions/`
4. New rule → extend Golden Rules or Anti-Patterns
5. Script or command changes → [reference/command-reference.md](./reference/command-reference.md)

---

## See also

- [Root README](../README.md)
- [AGENTS.md](../AGENTS.md)
