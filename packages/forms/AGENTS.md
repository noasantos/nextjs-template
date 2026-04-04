# `@workspace/forms`

**Audience:** agents / LLM.

## Filename suffixes (composition package)

Under `src/components/` use **`*.component.tsx`**. Under `src/hooks/` use
**`*.hook.ts`** (or `*.hook.tsx`).

Public imports stay stable (`package.json` → `exports`); only **on-disk** names
carry the suffix. Full rules:
[`docs/standards/package-file-suffixes.md`](../../docs/standards/package-file-suffixes.md).

## Unit tests (Vitest)

`vitest.config.ts` maps `@workspace/forms` → `src/`. Subpaths whose basename no
longer matches a short name (e.g. `form-field` → `form-field.component.tsx`)
need **explicit** `resolve.alias` entries — see `vitest.config.ts` and the doc
above.

## Boundaries

- Depends on `@workspace/ui` for primitives.
- Does **not** own Server Actions — those live in `@workspace/supabase-data`.
