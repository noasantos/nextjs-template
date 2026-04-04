---
name: tdd-workflow
description: >-
  Runs red-green-refactor TDD per GR-011. Use when implementing features, TDD,
  or test-first workflow.
---

# TDD Workflow Skill

## Purpose

Enforce Test-Driven Development workflow following GR-011 (TDD Required).

## When to Trigger

Auto-trigger when user:

- Implements new feature
- Mentions "TDD" or "test first"
- Starts working on task

## Skill Instructions

### **1. TDD Cycle**

```
1. Write failing test (RED)
2. Make test pass (GREEN)
3. Refactor (REFACTOR)
4. Repeat
```

### **2. Step by Step**

**Step 1: Write Failing Test**

```typescript
// tests/unit/my-module/my-function.test.ts
import { describe, it, expect } from "vitest"

describe("myFunction", () => {
  it("should return expected result", () => {
    const result = myFunction(input)
    expect(result).toBe(expected)
  })
})
```

**Step 2: Make Test Pass**

```typescript
// Minimal implementation
export function myFunction(input) {
  return expected // Just make it pass
}
```

**Step 3: Refactor**

```typescript
// Improve implementation
export function myFunction(input) {
  // Proper implementation
  // Clean code
  // Good naming
}
```

### **3. Coverage Requirements**

| Metric     | Minimum |
| ---------- | ------- |
| Lines      | 80%     |
| Statements | 80%     |
| Branches   | 75%     |
| Functions  | 80%     |

### **4. Enforce Rules**

- ✅ **GR-011**: Test first
- ✅ **RED-GREEN-REFACTOR**: Follow cycle
- ✅ **Coverage**: Meet thresholds
- ✅ **Location**: Tests in /tests

## Examples

### **User Request**

```
"I want to implement this feature"
```

### **Skill Response**

1. **STEP 1: Write test FIRST**

   ```bash
   # Create test file
   tests/unit/my-module/my-feature.test.ts
   ```

2. **STEP 2: Run test (should fail)**

   ```bash
   pnpm test
   # ❌ FAIL
   ```

3. **STEP 3: Implement minimal code**

   ```typescript
   // Make test pass
   ```

4. **STEP 4: Run test (should pass)**

   ```bash
   pnpm test
   # ✅ PASS
   ```

5. **STEP 5: Refactor**
   ```typescript
   // Improve code quality
   ```

## Related Skills

- **[test-generator](../test-generator/)** - Generate tests
- **[test-location-guide](../test-location-guide/)** - Test location
- **[rls-test-generator](../rls-test-generator/)** - RLS tests

## References

- **[GR-011: TDD Required](../../docs/standards/rules/tdd-required.md)**
- **[TDD Guide](../../docs/guides/tdd.md)**
- **[Testing Strategy](../../docs/architecture/testing.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
