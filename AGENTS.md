# AI Agent Instructions

**Main entry point for all AI agents working with this codebase.**

## 🚨 CRITICAL Rules (INSTANT REJECT IF VIOLATED)

**⚠️ READ THESE FIRST — YOUR PR WILL BE REJECTED IF YOU BREAK THESE:**

1. **[CRITICAL ARCHITECTURE RULES](./docs/architecture/CRITICAL-RULES.md)** — 5
   non-negotiable rules with examples
   - **Server Actions:** only in `packages/supabase-data/src/actions/<module>/`
     (`pnpm action:new`); apps **consume** only — no `"use server"` or
     `apps/*/actions/` (enforced by `pnpm check:forbidden`)
   - MUST use `.inputSchema()` (NEVER `.schema()`)
   - Zod validators MUST have `()` (`.uuid()` not `.uuid`)
   - NO server imports in client components
   - NO barrel exports (explicit imports only)

2. **[Proxy Not Middleware](./docs/standards/rules/proxy-not-middleware.md)** -
   Next.js 16 uses proxy.ts
3. **[Auth Invariants](./docs/standards/rules/auth-invariants.md)** -
   getClaims() vs getUser()
4. **[No Console Logging](./docs/standards/rules/no-console-logging.md)** - Use
   structured logging
5. **[Test File Location](./docs/standards/rules/test-file-location.md)** - All
   tests in /tests
6. **[CLI Migrations Only](./docs/standards/rules/cli-migrations-only.md)** -
   Never manual

**If you violate rule #1, your code WILL NOT MERGE. No exceptions.**

## 🛠️ Skills

**Auto-trigger based on context:**

- **server-action-template** - Create Server Actions
- **test-location-guide** - Guide to test location
- **logging-required** - Enforce structured logging
- **repository-pattern** - Implement repository pattern
- **edge-function-template** - Create Edge Functions
- **auth-invariants** - Auth patterns
- **security-check** - Security scan
- **jsdoc-generator** - Generate JSDoc
- **file-size-check** - Check file size
- **single-responsibility** - Enforce SRP
- **migration-workflow** - Migration workflow
- **rls-test-generator** - Generate RLS tests
- **test-generator** - Generate tests
- **tdd-workflow** - TDD workflow
- **three-level-docs** - Doc levels
- **doc-template** - Doc templates

**See [skills/README.md](./skills/README.md) for all 17 skills.**

## 📚 Documentation

**Golden Rules:**
[docs/standards/rules/README.md](./docs/standards/rules/README.md)  
**Composition package filenames:**
[docs/standards/package-file-suffixes.md](./docs/standards/package-file-suffixes.md)
— hub [`packages/AGENTS.md`](./packages/AGENTS.md) (`*.component.tsx` /
`*.hook.ts` / `*.provider.tsx` in `brand` / `core` / `forms` / `seo` only; not
`apps/`; not `packages/ui`)  
**Architecture:** [docs/architecture/](./docs/architecture/)  
**Guides:** [docs/guides/](./docs/guides/)  
**Testing:** [docs/architecture/testing.md](./docs/architecture/testing.md)  
**Oxlint / Oxfmt:** [docs/tools/oxlint-oxfmt.md](./docs/tools/oxlint-oxfmt.md) —
`packages/ui` is excluded from Oxlint (vendored shadcn); do not change UI source
to satisfy lint.

## 🔧 Commands

```bash
# Creation (always use templates)
pnpm action:new -- <module> <name>     # Server Action
pnpm edge:new -- <name>                # Edge Function
pnpm supabase:migration:new -- <name>  # Migration

# Testing
pnpm test                              # Unit tests
pnpm test:rls                          # RLS tests (mandatory)
pnpm test:all                          # All tests

# Skills
pnpm skills:update                     # Update from docs
```

## 🎯 Always

- ✅ Use skills when available
- ✅ Follow Golden Rules
- ✅ Log with structured logging
- ✅ Test in /tests directory
- ✅ Document with JSDoc
- ✅ Use templates for creation

## ❌ Never

- ❌ Suggest middleware.ts (use proxy.ts)
- ❌ Use getUser() for simple auth (use getClaims())
- ❌ Use console.log (use logServerEvent)
- ❌ Create tests outside /tests
- ❌ Create migrations manually
- ❌ Create barrel imports

---

**For:** All AI agents (Cursor, Claude, Copilot, Gemini)  
**Version:** 1.0.0  
**Last Updated:** 2026-04-04
