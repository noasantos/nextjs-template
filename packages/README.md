# Packages (`@workspace/*`)

Shared libraries consumed by `apps/*`. **Imports:** explicit subpath exports only—no barrel files ([docs/standards/repository-standards.md](../docs/standards/repository-standards.md), [GR-001](../docs/standards/golden-rules.md#gr-001-zero-barrel-policy)).
**Stack versions** (TypeScript, Zod, Tailwind, TanStack, …): [docs/reference/stack.md](../docs/reference/stack.md).

| Package                                            | Name                           | Purpose                                                                          |
| -------------------------------------------------- | ------------------------------ | -------------------------------------------------------------------------------- |
| [supabase-auth](./supabase-auth/)                  | `@workspace/supabase-auth`     | JWT/session claims, guards, proxy refresh, browser auth helpers                  |
| [supabase-infra](./supabase-infra/)                | `@workspace/supabase-infra`    | Service-role client helpers, generated DB types                                |
| [brand](./brand/README.md)                         | `@workspace/brand`             | Shared **hand-written** product UI (multi-app) on top of `@workspace/ui`         |
| [eslint-config](./eslint-config/README.md)         | `@workspace/eslint-config`     | Shared ESLint flat configs                                                       |
| [forms](./forms/)                                  | `@workspace/forms`             | TanStack Form + Zod field helpers                                                |
| [logging](./logging/README.md)                     | `@workspace/logging`           | Structured observability contracts, correlation, redaction, and runtime emitters |
| [supabase-data](./supabase-data/)                  | `@workspace/supabase-data`     | Repositories, mappers, domain modules, server actions                            |
| [test-utils](./test-utils/)                        | `@workspace/test-utils`        | Supabase test clients, env bootstrap (used from `tests/` via `@workspace/tests`) |
| [typescript-config](./typescript-config/README.md) | `@workspace/typescript-config` | Shared `tsconfig` bases                                                          |
| [ui](./ui/README.md)                               | `@workspace/ui`                | shadcn primitives (**read-only**; add via CLI)                                   |
| [vitest-config](./vitest-config/README.md)         | `@workspace/vitest-config`     | Shared Vitest coverage thresholds and presets                                    |

**Workspace package at repo root:** [`tests/package.json`](../tests/package.json) — **`@workspace/tests`** runs DB integration and RLS Vitest projects; see [`tests/README.md`](../tests/README.md).

**Canonical standards:** [docs/standards/repository-standards.md](../docs/standards/repository-standards.md)
