---
name: server-action-template
description: >-
  Generates Server Actions with structured logging, error handling, and type
  safety per GR-005, GR-017, and GR-021. Use when creating Server Actions,
  running pnpm action:new, or implementing business logic in actions.
---

# Server Action Template Skill

## Purpose

Generate Server Actions with proper logging, error handling, and type safety
following GR-005, GR-017, and GR-021.

## When to Trigger

Auto-trigger when user:

- Asks to "create a Server Action"
- Mentions "action" + module name
- Wants to implement business logic

## Skill Instructions

### **1. Use Template Command**

```bash
pnpm action:new -- <module> <action-name>
```

This creates template with:

- ✅ Logging already configured
- ✅ Error handling setup
- ✅ Type safety
- ✅ JSDoc comments

### **2. Follow Structure**

```typescript
"use server"

import { z } from "zod"
import { logServerEvent } from "@workspace/logging/server"
import { getClaims } from "@workspace/supabase-auth/session"
import { AppError } from "@workspace/supabase-data/lib/errors/app-error"
import { ok, err } from "@workspace/supabase-data/lib/boundary/result"
import { serializeResult } from "@workspace/supabase-data/lib/boundary/serialize-result"
import type { ActionResult } from "@workspace/supabase-data/lib/boundary/action-result"

/**
 * [Action name] Server Action
 *
 * [Brief description]
 *
 * @param input - Action input
 * @returns Action result
 *
 * @module @workspace/supabase-data/actions/{module}/{action}
 */
export async function {actionName}Action(
  input: {InputType}
): Promise<ActionResult<{OutputType}>> {
  const startedAt = Date.now()
  const claims = await getClaims()

  // Auth check
  if (!claims?.sub) {
    await logServerEvent({
      component: "{module}.{action}",
      eventFamily: "security.audit",
      eventName: "{action}_unauthorized",
      outcome: "failure",
      service: "supabase-data",
    })
    return serializeResult(err(AppError.auth("Unauthorized")))
  }

  const userId = claims.sub

  try {
    // Validate input
    const validated = {InputSchema}.parse(input)

    // Business logic
    const supabase = await createServerAuthClient()
    const repository = new {Repository}(supabase)
    const result = await repository.{method}(validated)

    // Log success
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "{module}.{action}",
      eventFamily: "action.lifecycle",
      eventName: "{action}_success",
      outcome: "success",
      durationMs: Date.now() - startedAt,
      metadata: {
        // Add relevant metadata
      },
      service: "supabase-data",
    })

    return serializeResult(ok(result))
  } catch (error) {
    // Log error
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "{module}.{action}",
      eventFamily: "action.lifecycle",
      eventName: "{action}_failed",
      outcome: "failure",
      error,
      durationMs: Date.now() - startedAt,
      service: "supabase-data",
    })

    return serializeResult(err(AppError.infra("Failed", { cause: error })))
  }
}
```

### **3. Enforce Rules**

- ✅ **GR-005**: Always use `logServerEvent`
- ✅ **GR-017**: Return `ActionResult<T>`
- ✅ **GR-021**: Add JSDoc to function
- ✅ **SRP**: One action per file
- ✅ **Logging**: Log at start, success, error

### **4. Create Tests**

Guide user to create tests in:

```
tests/integration/supabase-data/actions/{module}/{action}.integration.test.ts
```

## Examples

### **User Request**

```
"Create a Server Action for updating task status"
```

### **Skill Response**

1. **RUN template:**

   ```bash
   pnpm action:new -- tasks update-task-status
   ```

2. **GUIDE implementation:**
   - Define input schema
   - Implement business logic
   - Add logging metadata
   - Create integration test

3. **REMIND rules:**
   - "Don't forget to add JSDoc (GR-021)"
   - "Remember to log at start, success, and error (GR-005)"
   - "Return ActionResult type (GR-017)"

## Related Skills

- **[repository-pattern](../repository-pattern/)** - For repository
  implementation
- **[test-generator](../test-generator/)** - For integration tests
- **[jsdoc-generator](../jsdoc-generator/)** - For documentation

## References

- **[Server Actions Guide](../../docs/architecture/server-actions.md)**
- **[GR-005: No Console Logging](../../docs/standards/rules/no-console-logging.md)**
- **[GR-017: Server Actions Boundary](../../docs/standards/rules/server-actions-boundary.md)**
- **[GR-021: JSDoc Required](../../docs/standards/rules/jsdoc-required.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
