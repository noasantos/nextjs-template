---
name: test-location-guide
description: >-
  Guides placement of tests under /tests per GR-010. Use when placing tests,
  creating test files, or asking where tests belong.
---

# Test Location Guide Skill

## Purpose

Guide developers to create tests in the CORRECT location following GR-010 (Test
File Location).

## When to Trigger

Auto-trigger when user:

- Asks "where to put test"
- Creates test file outside `/tests`
- Mentions "test" + file location

## Skill Instructions

### **1. Decision Tree**

```
Is it testing RLS for a database table?
└─ YES → tests/rls/supabase-data/{table}.rls.test.ts

Is it testing with real database?
└─ YES → tests/integration/{package}/{feature}.integration.test.ts

Is it testing pure logic (no DB)?
└─ YES → tests/unit/{mirror-structure}/{file}.test.ts
```

### **2. Enforce Location Rule**

**ALWAYS:**

```
✅ tests/unit/supabase-data/actions/tasks.test.ts
✅ tests/integration/supabase-data/actions/tasks.test.ts
✅ tests/rls/supabase-data/tasks.rls.test.ts
```

**NEVER:**

```
❌ packages/supabase-data/src/actions/tasks.test.ts
❌ apps/web/app/dashboard/page.test.tsx
```

### **3. Mirror Structure**

For unit tests, mirror the source structure:

```
Source:  packages/supabase-data/src/modules/tasks/task-repository.ts
Test:    tests/unit/supabase-data/src/modules/tasks/task-repository.test.ts
```

### **4. RLS Tests Mandatory**

For EVERY database table:

```typescript
// tests/rls/supabase-data/{table}.rls.test.ts
describe("{Table} RLS", () => {
  it("allows user to view their own data", async () => {
    // Test own data access
  })

  it("prevents user from viewing other users' data", async () => {
    // Test data isolation
  })

  it("allows authenticated user to create row", async () => {
    // Test insert permission
  })

  it("prevents unauthenticated insert", async () => {
    // Test auth requirement
  })
})
```

## Examples

### **User Request**

```
"Where should I put the test for task repository?"
```

### **Skill Response**

**IF unit test (no DB):**

```
Create test in:
tests/unit/supabase-data/src/modules/tasks/task-repository.test.ts

This mirrors the source structure:
packages/supabase-data/src/modules/tasks/task-repository.ts
```

**IF integration test (with DB):**

```
Create test in:
tests/integration/supabase-data/modules/tasks/task-repository.integration.test.ts

This uses real Supabase database.
```

### **User Request**

```
"I created a new users table, what tests do I need?"
```

### **Skill Response**

```
🚨 RLS Tests MANDATORY (GR-016)

Create: tests/rls/supabase-data/users.rls.test.ts

Test all 4 operations:
1. SELECT - allows user to view own data
2. SELECT - prevents viewing other users' data
3. INSERT - allows authenticated user to create
4. INSERT - prevents unauthenticated insert
5. UPDATE - allows user to update own data
6. UPDATE - prevents updating other users' data
7. DELETE - allows user to delete own data
8. DELETE - prevents deleting other users' data

Run: pnpm test:rls
```

## Related Skills

- **[rls-test-generator](../rls-test-generator/)** - Generate RLS tests
- **[test-generator](../test-generator/)** - Generate unit/integration tests
- **[tdd-workflow](../tdd-workflow/)** - Enforce TDD workflow

## References

- **[GR-010: Test File Location](../../docs/standards/rules/test-file-location.md)**
- **[GR-016: RLS Tests Mandatory](../../docs/standards/rules/rls-tests-mandatory.md)**
- **[Testing Strategy](../../docs/architecture/testing.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
