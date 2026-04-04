# Product documentation (cross-app) — `apps/docs`

**Audience:** agents / LLM.

**Level 2** in the doc hierarchy:
[GR-019](../../docs/standards/golden-rules.md#gr-019-three-level-documentation-layout).

## What belongs here

**Business / product** docs that apply to **more than one app** under `apps/`,
or the **product as a whole** — not engineering-template-only content.

Examples: domain glossary, cross-surface journeys, product-wide release notes,
cross-app roles/permissions in product language (link to code/RLS in packages
when needed).

## What does not belong here

- Repo/template standards (lint, migrations, stack, agent rules) → root
  **`docs/`**
- Single-deployable-only detail → **`apps/<that-app>/docs/`**

## Routing table (LLMs)

| Question                                  | Place                   |
| ----------------------------------------- | ----------------------- |
| pnpm, Turbo, Supabase CLI, GR-0xx, AGENTS | Root **`docs/`**        |
| Business/product shared by several apps   | **`apps/docs/`** (here) |
| Only one app’s domain/UI/ops              | **`apps/<app>/docs/`**  |

See also: [apps/README.md](../README.md),
[repository standards § three-level docs](../../docs/standards/repository-standards.md#three-level-documentation-layout).
