# Package file suffixes (composition packages)

**Canonical reference for humans and CI.** Keep **`PACKAGE_SUFFIX_CONVENTION`**
in [`scripts/ci/check-forbidden.mjs`](../../scripts/ci/check-forbidden.mjs) in
sync when adding a new **composition** package to the monorepo.

## Which packages

| Package                                                                                 | Suffix rules apply?                                                    |
| --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `packages/brand`                                                                        | Yes                                                                    |
| `packages/core`                                                                         | Yes                                                                    |
| `packages/forms`                                                                        | Yes                                                                    |
| `packages/seo`                                                                          | Yes (today mostly `*.ts`; if you add components/hooks, use suffixes)   |
| `packages/ui`                                                                           | **No** — shadcn output only; agents do not edit for naming conventions |
| `packages/supabase-data`, `supabase-infra`, `supabase-auth`, `logging`, `test-utils`, … | **No** — domain/infra; use normal module names                         |

## Rules (under `src/`)

| Location                                | Filename pattern            | Notes                            |
| --------------------------------------- | --------------------------- | -------------------------------- |
| `**/components/**`                      | `*.component.tsx`           | React components (JSX).          |
| `**/hooks/**`                           | `*.hook.ts` or `*.hook.tsx` | Custom hooks only.               |
| `**/providers/**` or `**/_providers/**` | `*.provider.tsx`            | React provider components (JSX). |

Plain `*.ts` modules (e.g. `providers/query-client.ts`, `lib/*.ts`,
`src/index.ts`) stay **without** these suffixes when they are not JSX
providers/components.

## Checklist (new code)

1. **Hook** — Create under `src/hooks/` as `my-feature.hook.ts` (or
   `.hook.tsx`). Do **not** use `use-my-feature.ts` without the `.hook` segment
   before the extension.
2. **Component** — Create under `src/components/` as `my-widget.component.tsx`.
3. **Provider** — Create under `src/providers/` or `src/_providers/` as
   `my-context.provider.tsx`.
4. **`package.json` `exports`** — Point to the suffixed file; keep **stable**
   import subpaths (e.g. `./hooks/use-my-feature` →
   `./src/hooks/use-my-feature.hook.ts`).
5. **Vitest** — If tests alias `@workspace/<pkg>` to `src/`, add explicit
   `resolve.alias` for any export whose basename no longer matches the file stem
   (see `packages/forms/vitest.config.ts`).

## Apps (`apps/<app>/`)

**Do not** use `.hook`, `.component`, or `.provider` in filenames. Use folders
(`_hooks/`, `_providers/`, route segments) and keep Next defaults (`page.tsx`,
`layout.tsx`, `route.ts`, …). **CI:** `pnpm check:forbidden`.

## Imports

Public `package.json` `exports` keys stay stable (e.g.
`@workspace/core/components/theme-provider`); only **disk** filenames use the
suffixes above.

**`@workspace/forms` unit tests:** `packages/forms/vitest.config.ts` aliases
`@workspace/forms` to `src/` for resolution; subpaths that no longer match a
basename without a suffix list explicit `*.component.tsx` / `*.hook.ts` targets
so Vitest can resolve them.

## See also

- [`packages/AGENTS.md`](../../packages/AGENTS.md) — package hub (scope vs
  infra)
- [`apps/AGENTS.md`](../../apps/AGENTS.md) — app layout vs packages
- [`scripts/ci/check-forbidden.mjs`](../../scripts/ci/check-forbidden.mjs) —
  enforcement
