# Product documentation (cross-app)

This folder is **Level 2** in the documentation hierarchy ([GR-019](../../docs/standards/golden-rules.md#gr-019-three-level-documentation-layout)).

## What belongs here

Put **business and product documentation** that applies **across more than one app** under `apps/`, or that describes the **product as a whole** — not the engineering template.

Examples:

- Domain glossary and shared entities (concepts used by more than one app under `apps/`)
- User journeys or flows that span multiple surfaces
- Product-wide release notes or stakeholder summaries (non-technical or mixed audience)
- Cross-app permissions, roles, or data rules **described in product terms** (link to code/RLS in packages when needed)

## What does *not* belong here

- **Repository / template standards** (lint, migrations, stack versions, agent rules) → monorepo root **`docs/`**
- **Deep detail for a single app only** (one deployable’s routes, one map feature, one admin section) → **`apps/<that-app>/docs/`**

## For LLMs

| Question | Place documentation in |
|----------|-------------------------|
| Is it about **pnpm, Turbo, Supabase CLI, GR-0xx, AGENTS**? | Root **`docs/`** |
| Is it **business/product** but **shared** by several apps or the whole product? | **`apps/docs/`** (here) |
| Is it **only** about one app’s domain/UI/ops? | **`apps/<app>/docs/`** |

---

See also: [apps/README.md](../README.md), [docs/standards/repository-standards.md § Three-level documentation](../../docs/standards/repository-standards.md#three-level-documentation-layout).
