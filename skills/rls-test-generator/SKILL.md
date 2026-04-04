---
name: rls-test-generator
description: >-
  Generates RLS test scaffolding per GR-016. Use when creating tables, changing
  RLS policies, or adding RLS tests.
---

# RLS Test Generator Skill

## Purpose

Generate RLS tests for every database table following GR-016 (RLS Tests
Mandatory).

## When to Trigger

Auto-trigger when user:

- Creates new table
- Mentions "RLS test" or "security test"
- Modifies RLS policies

## Skill Instructions

### **1. Test Structure**

```typescript
// tests/rls/supabase-data/{table}.rls.test.ts
import { describe, it, expect, beforeAll } from "vitest"
import { createClient } from "@supabase/supabase-js"

describe("{Table} RLS", () => {
  let user1Client: TypedSupabaseClient
  let user2Client: TypedSupabaseClient
  let anonClient: TypedSupabaseClient

  beforeAll(async () => {
    // Create test users
    user1Client = await createTestClient("user-1")
    user2Client = await createTestClient("user-2")
    anonClient = createAnonClient()
  })

  describe("SELECT policies", () => {
    it("allows user to view their own data", async () => {
      // Test own data access
    })

    it("prevents user from viewing other users' data", async () => {
      // Test data isolation
    })
  })

  describe("INSERT policies", () => {
    it("allows authenticated user to create row", async () => {
      // Test insert permission
    })

    it("prevents unauthenticated insert", async () => {
      // Test auth requirement
    })
  })

  describe("UPDATE policies", () => {
    it("allows user to update their own data", async () => {
      // Test own data update
    })

    it("prevents user from updating other users' data", async () => {
      // Test update isolation
    })
  })

  describe("DELETE policies", () => {
    it("allows user to delete their own data", async () => {
      // Test own data delete
    })

    it("prevents user from deleting other users' data", async () => {
      // Test delete isolation
    })
  })
})
```

### **2. Enforce Rules**

- ✅ **GR-016**: RLS tests for EVERY table
- ✅ **4 Operations**: SELECT, INSERT, UPDATE, DELETE
- ✅ **2 Scenarios**: Authorized, Unauthorized
- ✅ **Real DB**: Use Supabase local

### **3. When Required**

- ✅ New table created
- ✅ RLS policy modified
- ✅ Schema changed
- ✅ Before production deploy

## Examples

### **User Request**

```
"Generate RLS tests for tasks table"
```

### **Skill Response**

1. **CREATE file:**

   ```
   tests/rls/supabase-data/tasks.rls.test.ts
   ```

2. **GENERATE tests:**
   - SELECT: own data, other data
   - INSERT: authenticated, unauthenticated
   - UPDATE: own data, other data
   - DELETE: own data, other data

3. **RUN tests:**
   ```bash
   pnpm test:rls
   ```

## Related Skills

- **[test-location-guide](../test-location-guide/)** - Test location
- **[migration-workflow](../migration-workflow/)** - Migration workflow
- **[test-generator](../test-generator/)** - General tests

## References

- **[GR-016: RLS Tests Mandatory](../../docs/standards/rules/rls-tests-mandatory.md)**
- **[Testing Strategy](../../docs/architecture/testing.md)**
- **[RLS Guide](../../docs/guides/rls.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
