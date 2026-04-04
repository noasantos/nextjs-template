# Packages (`packages/`) — agents

**Audience:** agents / LLM. Per-package notes live in each
`packages/<name>/AGENTS.md` when present.

## Composition packages (filename suffixes)

These packages **must** use disk suffixes for React components, hooks, and
providers under `src/`:

| Package            | Role                                                                                 |
| ------------------ | ------------------------------------------------------------------------------------ |
| `@workspace/brand` | Product UI above `@workspace/ui`                                                     |
| `@workspace/core`  | Shared app infra (providers, theme, cross-app hooks)                                 |
| `@workspace/forms` | Shared form primitives / hooks                                                       |
| `@workspace/seo`   | SEO helpers; if you add `src/components/` or `src/hooks/`, use the same suffix rules |

**Canonical doc:**
[`docs/standards/package-file-suffixes.md`](../docs/standards/package-file-suffixes.md)
— `*.component.tsx`, `*.hook.ts` / `*.hook.tsx`, `*.provider.tsx`, folders
(`components/`, `hooks/`, `providers/`, `_providers/`), exceptions (`lib/`,
non-JSX `*.ts` in `providers/`).

**CI:** `pnpm check:forbidden` (same script as other forbidden checks).

## Explicitly **out of scope** for suffix rules

- **`packages/ui`** — shadcn only; **never** hand-edit for suffix conventions
  ([`packages/ui/AGENTS.md`](./ui/AGENTS.md)).
- **`packages/supabase-data`**, **`supabase-infra`**, **`supabase-auth`**,
  **`logging`**, **`test-utils`**, **`vitest-config`**, **`typescript-config`**,
  etc. — domain/infra; no `*.component.tsx` requirement.

## Apps vs packages

- **`apps/`** — **no** `.hook` / `.component` / `.provider` **in filenames**;
  use folders (`_hooks/`, `_providers/`). See
  [`apps/AGENTS.md`](../apps/AGENTS.md).
