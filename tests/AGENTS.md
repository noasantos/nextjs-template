# tests

Centralized test directory - ALL tests live here.

## 🚨 CRITICAL

**Read before using:**

- [Test File Location](../docs/standards/rules/test-file-location.md)
- [Testing Strategy](../docs/architecture/testing.md)

## 📁 Structure

```
tests/
├── unit/                    # Mirror structure
├── integration/             # Real DB
├── rls/                     # Per table (MANDATORY)
└── mocks/
```

## 🔒 Golden Rule

**ALL tests in /tests. No exceptions (except pgTAP).**

```
✅ tests/unit/supabase-data/actions/tasks.test.ts
❌ packages/supabase-data/src/actions/tasks.test.ts
```

## 📊 Test Types

**Unit:** tests/unit/ (mirror structure, no DB)  
**Integration:** tests/integration/ (real DB)  
**RLS:** tests/rls/ (per table, mandatory)  
**pgTAP:** supabase/tests/ (DB functions, only exception)

## 📖 Full Docs

[Test File Location](../docs/standards/rules/test-file-location.md)  
[Testing Strategy](../docs/architecture/testing.md)

---

**For AI Agents:** This is the ONLY place for tests. ALWAYS mirror structure.
ALWAYS create RLS tests for tables.
