# @workspace/logging

Structured logging package for server-side operations.

## 🚨 CRITICAL: Layer Responsibilities

### ✅ Where to Use Logging

**Data Layer (`packages/supabase-data/`):**

- ✅ Server Actions
- ✅ Repositories
- ✅ Business logic

**Auth Layer (`packages/supabase-auth/`):**

- ✅ Auth guards
- ✅ Session management
- ✅ Security checks

**Infra Layer (`packages/supabase-infra/`):**

- ✅ Database clients
- ✅ Infrastructure operations

### ❌ Where NOT to Use Logging

**Apps Layer (`apps/web/`):**

- ❌ UI Components
- ❌ Pages
- ❌ Client Components

**Why:** Apps layer should delegate to Server Actions which handle logging.

## Architecture

```
┌─────────────────────────────────────┐
│  Apps Layer (apps/web)              │
│  ❌ NO direct logging               │
│     Use Server Actions instead      │
└─────────────────────────────────────┘
               ↓ calls
┌─────────────────────────────────────┐
│  Data Layer (@workspace/supabase-data) │
│  ✅ Server Actions with logging     │
│     logServerEvent({...})           │
└─────────────────────────────────────┘
```

## Usage

### Server-Side (Primary)

```typescript
import { logServerEvent } from "@workspace/logging/server"

export async function myServerAction() {
  const startedAt = Date.now()

  try {
    // ... operation
    await logServerEvent({
      component: "my.component",
      eventFamily: "action.lifecycle",
      eventName: "operation_completed",
      outcome: "success",
      durationMs: Date.now() - startedAt,
      service: "supabase-data",
    })
  } catch (error) {
    await logServerEvent({
      component: "my.component",
      eventFamily: "action.lifecycle",
      eventName: "operation_failed",
      outcome: "failure",
      error,
      durationMs: Date.now() - startedAt,
      service: "supabase-data",
    })
    throw error
  }
}
```

### Client-Side (Fallback)

```typescript
"use client"

import { logClientEvent } from "@workspace/logging/client"

export function MyComponent() {
  const handleClick = async () => {
    await logClientEvent({
      component: "my.component",
      eventFamily: "ui.event",
      eventName: "button_clicked",
      outcome: "success",
    })
  }

  return <button onClick={handleClick}>Click</button>
}
```

### Edge Functions

```typescript
import { logEdgeEvent } from "@workspace/logging/edge"

serve(async (req) => {
  await logEdgeEvent(req, {
    component: "my-function",
    eventFamily: "edge.request",
    eventName: "function_executed",
    outcome: "success",
  })
})
```

## Event Families

| Family                 | Use Case          |
| ---------------------- | ----------------- |
| `action.lifecycle`     | Server Actions    |
| `auth.flow`            | Login, logout     |
| `security.audit`       | Permission checks |
| `http.request`         | API requests      |
| `supabase.integration` | DB operations     |
| `ui.error`             | Client errors     |

## Scripts

### Generate Server Action Template

```bash
pnpm action:new -- <module> <action-name>

# Example
pnpm action:new -- tasks create-task
```

This creates a Server Action with:

- ✅ Logging already configured
- ✅ Error handling setup
- ✅ Type safety
- ✅ TODO comments for customization
