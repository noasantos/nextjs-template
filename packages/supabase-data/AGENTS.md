# @workspace/supabase-data

Data layer: repositories, Server Actions, hooks.

## 🚨 CRITICAL

**Read before using:**

- [Repository Pattern](../../docs/standards/rules/repository-pattern.md)
- [Server Actions](../../docs/architecture/server-actions.md)
- [Logging Required](../../docs/standards/rules/no-console-logging.md)
- [Test File Location](../../docs/standards/rules/test-file-location.md)

## 🎯 Architecture

```
apps/web/              ❌ NO direct data access
    ↓
packages/supabase-data/ ✅ Server Actions, Repositories, Logging
    ↓
packages/supabase-infra/ ✅ Database clients
```

**Actions path:** `src/actions/<module>/` is the canonical Server Actions tree
(see `pnpm action:new`). Optional `*.action.ts` filenames are fine for
traceability; not required for every export. **Suffix rules**
(`*.component.tsx`, etc.) apply only to `brand` / `core` / `forms` / `seo` — not
this package; see
[`docs/standards/package-file-suffixes.md`](../../docs/standards/package-file-suffixes.md).

## 📦 Module Structure

```
modules/{module}/
├── domain/
│   ├── dto/
│   ├── schemas/
│   └── ports/
└── infrastructure/
    ├── mappers/
    └── repositories/
```

## 🧪 Testing

**ALL tests in /tests:**

```
tests/unit/supabase-data/
tests/integration/supabase-data/
tests/rls/supabase-data/
```

## 📖 Full Docs

[Repository Pattern](../../docs/standards/rules/repository-pattern.md)  
[Server Actions](../../docs/architecture/server-actions.md)  
[Testing](../../docs/architecture/testing.md)

---

**For AI Agents:** This is the BUSINESS LOGIC layer. ALWAYS use repositories.
ALWAYS log. ALWAYS test in /tests.
