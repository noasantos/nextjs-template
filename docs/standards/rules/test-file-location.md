> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/test-file-location.mdc`](../../../.cursor/rules/test-file-location.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# 🧪 Test File Location Mandatory

**This is a CURSOR-SPECIFIC rule file.**

**Full documentation:**
[docs/standards/rules/test-file-location.md](../../docs/standards/rules/test-file-location.md)

## Rule for Cursor

Cursor MUST enforce test location rule:

- **NEVER** suggest tests in source directories
- **ALWAYS** create tests in `/tests`
- **FAIL** if test files found outside `/tests`

## Quick Reference

```
✅ CORRECT:
tests/unit/supabase-data/actions/tasks.test.ts
tests/integration/supabase-data/actions/tasks.test.ts
tests/rls/supabase-data/tasks.rls.test.ts

❌ FORBIDDEN:
packages/supabase-data/src/actions/tasks.test.ts
apps/web/app/dashboard/page.test.tsx
```

## Decision Tree

```
Testing RLS for a table?
└─ YES → tests/rls/supabase-data/{table}.rls.test.ts

Testing with real database?
└─ YES → tests/integration/{package}/{feature}.integration.test.ts

Testing pure logic (no DB)?
└─ YES → tests/unit/{mirror-structure}/{file}.test.ts
```

## AI Agent Instructions

When creating tests:

1. ALWAYS use `/tests` directory
2. MIRROR source structure for unit tests
3. CREATE RLS tests for database tables
4. NEVER create tests in source directories

---

**Rule ID:** TEST-FILE-LOCATION  
**Severity:** CRITICAL  
**Full Docs:**
[docs/standards/rules/test-file-location.md](../../docs/standards/rules/test-file-location.md)
