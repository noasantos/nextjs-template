---
name: test-generator
description: >-
  Generates tests in correct locations per GR-010, GR-011, and GR-012. Use when
  adding unit, integration, or RLS tests.
---

# Test Generator Skill

## Purpose

Generate unit and integration tests in correct locations following GR-010,
GR-011, and GR-012.

## When to Trigger

Auto-trigger when user:

- Creates new feature
- Mentions "test" or "testing"
- Wants to add tests

## Skill Instructions

### **1. Location Decision Tree**

```
Is it testing RLS for a database table?
└─ YES → tests/rls/supabase-data/{table}.rls.test.ts

Is it testing with real database?
└─ YES → tests/integration/{package}/{feature}.integration.test.ts

Is it testing pure logic (no DB)?
└─ YES → tests/unit/{mirror-structure}/{file}.test.ts
```

### **2. Unit Test Template**

```typescript
// tests/unit/supabase-data/modules/tasks/task-repository.test.ts
import { describe, it, expect, vi } from "vitest"
import { TaskRepository } from "@workspace/supabase-data/modules/tasks"

describe("TaskRepository", () => {
  it("creates a task", async () => {
    const mockSupabase = createMockSupabase()
    const repo = new TaskRepository(mockSupabase)

    const task = await repo.create({ title: "Test" })

    expect(task.title).toBe("Test")
  })
})
```

### **3. Integration Test Template**

```typescript
// tests/integration/supabase-data/actions/tasks/create-task.integration.test.ts
import { describe, it, expect, beforeAll } from "vitest"
import { createTaskAction } from "@workspace/supabase-data/actions/tasks/create-task"

describe("Create Task Integration", () => {
  beforeAll(async () => {
    // Seed test data
  })

  it("creates a task with real DB", async () => {
    const result = await createTaskAction({ title: "Test" })

    expect(result.success).toBe(true)
  })
})
```

### **4. Enforce Rules**

- ✅ **GR-010**: Tests in /tests only
- ✅ **GR-011**: TDD (test first)
- ✅ **GR-012**: All features tested
- ✅ **Mirror**: Unit tests mirror structure

## Examples

### **User Request**

```
"Create tests for task repository"
```

### **Skill Response**

1. **DETERMINE type:**
   - Unit test (no DB) → tests/unit/
   - Integration test (with DB) → tests/integration/

2. **CREATE file:**

   ```
   tests/unit/supabase-data/modules/tasks/task-repository.test.ts
   ```

3. **GENERATE tests:**
   - Create test
   - Read test
   - Update test
   - Delete test

## Related Skills

- **[test-location-guide](../test-location-guide/)** - Location guidance
- **[rls-test-generator](../rls-test-generator/)** - RLS tests
- **[tdd-workflow](../tdd-workflow/)** - TDD workflow

## References

- **[GR-010: Test File Location](../../docs/standards/rules/test-file-location.md)**
- **[GR-011: TDD Required](../../docs/standards/rules/tdd-required.md)**
- **[GR-012: Tests mandatory](../../docs/standards/rules/tdd-required.md)**
  (with
  [GR-010: Test file location](../../docs/standards/rules/test-file-location.md))
- **[Testing Strategy](../../docs/architecture/testing.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
