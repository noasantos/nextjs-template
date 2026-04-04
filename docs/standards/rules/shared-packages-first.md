> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/shared-packages-first.mdc`](../../../.cursor/rules/shared-packages-first.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# Shared packages over app-local code

**This is a CURSOR-SPECIFIC rule file.**

**Canonical doc:**
[docs/architecture/core-package.md](../../docs/architecture/core-package.md)

## Rule for Cursor

Cursor MUST enforce the **monorepo package hierarchy**:

### Prefer shared packages

When creating new code, check if it belongs in a shared package:

```
Will multiple apps use this?
└─ YES → Put it in @workspace/* (usually @workspace/core for shared UI infra, or the right domain package)
└─ NO  → May stay in apps/ (app-specific)
```

### Do not duplicate shared logic in apps

**Wrong:** defining `QueryClient`, root `ThemeProvider`, or copy-pasted provider
trees under `apps/<name>/` when they should be shared.

**Right:** use `@workspace/core/providers/app` (or extend it in a thin app
wrapper under `apps/<name>/app/_providers/`).

### `@workspace/core` responsibilities

- Shared **providers** (React Query defaults, theme, composition with
  `@workspace/ui` toaster/tooltip)
- Shared **components** that are not shadcn primitives (e.g. theme provider with
  hotkey)
- Shared **hooks** (e.g. `useMounted`)

### What stays out of `core`

- shadcn primitives → `@workspace/ui` (CLI-managed)
- Auth / Supabase → `@workspace/supabase-*`
- Forms → `@workspace/forms`
- Structured logging → `@workspace/logging`

### `@workspace/brand`

Legacy path `@workspace/brand/components/theme-provider` **re-exports** from
`@workspace/core`. New code MUST import from
`@workspace/core/components/theme-provider`.

## Decision tree

```
New provider / hook / shared component?
├─ Used by more than one app? → packages/core (or domain package)
├─ shadcn primitive? → packages/ui (CLI)
├─ One app only? → apps/<name>/
└─ Unsure? → Read docs/architecture/core-package.md
```

## Related rules

- [zero-barrel-policy.mdc](./zero-barrel-policy.mdc)
- [respect-architectural-boundaries.mdc](./respect-architectural-boundaries.mdc)
- [packages-ui-immutable.mdc](./packages-ui-immutable.mdc)

---

**Rule ID:** SHARED-PACKAGES-FIRST  
**Severity:** CRITICAL
