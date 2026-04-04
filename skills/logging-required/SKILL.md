---
name: logging-required
description: >-
  Enforces structured logging via @workspace/logging instead of console per
  GR-005. Use when creating Server Actions, Edge Functions, or business logic
  that might use console.log.
---

# Logging Required Skill

## Purpose

Ensure ALL business logic uses structured logging following GR-005 (No Console
Logging).

## When to Trigger

Auto-trigger when user:

- Creates Server Action
- Implements business logic
- Uses `console.log`
- Creates Edge Function

## Skill Instructions

### **1. Server-Side Logging**

```typescript
import { logServerEvent } from "@workspace/logging/server"

// ✅ CORRECT - Structured logging
await logServerEvent({
  component: "my.component",
  eventFamily: "action.lifecycle",
  eventName: "operation_completed",
  outcome: "success",
  durationMs: Date.now() - startedAt,
  service: "supabase-data",
  metadata: {
    userId: claims.sub,
    itemId: result.id,
  },
})

// ❌ FORBIDDEN - Raw console
console.log("Operation completed")
```

### **2. Edge Function Logging**

```typescript
import { logEdgeEvent } from "@workspace/logging/edge"

await logEdgeEvent(request, {
  component: "my-function",
  eventFamily: "edge.request",
  eventName: "function_executed",
  outcome: "success",
  durationMs: Date.now() - startedAt,
})
```

### **3. Client-Side Logging**

```typescript
import { logClientEvent } from "@workspace/logging/client"

await logClientEvent({
  component: "my.component",
  eventFamily: "ui.event",
  eventName: "button_clicked",
  outcome: "success",
})
```

### **4. Error Logging**

```typescript
try {
  // Business logic
} catch (error) {
  await logServerEvent({
    component: "my.component",
    eventFamily: "action.lifecycle",
    eventName: "operation_failed",
    outcome: "failure",
    error, // Auto-categorized
    durationMs: Date.now() - startedAt,
    metadata: {
      errorType: error.constructor.name,
      errorMessage: getErrorMessage(error),
      errorCode: getErrorCode(error),
    },
  })
  throw error
}
```

### **5. Rich Context**

Always include:

- ✅ **component** - Where it happened
- ✅ **eventFamily** - Category (action.lifecycle, edge.request, etc.)
- ✅ **eventName** - What happened
- ✅ **outcome** - success/failure/unknown
- ✅ **durationMs** - Performance metric
- ✅ **metadata** - Rich context (auto-redacted)

## Examples

### **User Request**

```
"Implement this Server Action"
```

### **Skill Response**

```typescript
"use server"

import { logServerEvent } from "@workspace/logging/server"

export async function myAction(input: Input) {
  const startedAt = Date.now()
  const claims = await getClaims()

  try {
    // Business logic

    // ✅ Log success
    await logServerEvent({
      component: "my-module.my-action",
      eventFamily: "action.lifecycle",
      eventName: "my_action_success",
      outcome: "success",
      durationMs: Date.now() - startedAt,
      actorId: claims.sub,
      metadata: {
        inputId: input.id,
      },
      service: "supabase-data",
    })

    return serializeResult(ok(result))
  } catch (error) {
    // ✅ Log error
    await logServerEvent({
      component: "my-module.my-action",
      eventFamily: "action.lifecycle",
      eventName: "my_action_failed",
      outcome: "failure",
      error,
      durationMs: Date.now() - startedAt,
      service: "supabase-data",
    })
    throw error
  }
}
```

## Related Skills

- **[server-action-template](../server-action-template/)** - For Server Actions
- **[edge-function-template](../edge-function-template/)** - For Edge Functions
- **[security-check](../security-check/)** - For security scanning

## References

- **[GR-005: No Console Logging](../../docs/standards/rules/no-console-logging.md)**
- **[Logging Architecture](../../docs/architecture/logging.md)**
- **[Edge Functions](../../docs/architecture/edge-functions.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
