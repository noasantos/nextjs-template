# @workspace/logging

Structured logging for server, client, and edge.

## 🚨 CRITICAL

**Read before using:**

- [Logging Architecture](../../docs/architecture/logging.md)
- [GR-005: No Console Logging](../../docs/standards/rules/no-console-logging.md)

## 📦 Exports

```typescript
// Server-side (primary)
import { logServerEvent } from "@workspace/logging/server"

// Client-side (fallback)
import { logClientEvent } from "@workspace/logging/client"

// Edge Functions
import { logEdgeEvent } from "@workspace/logging/edge"
```

## 🎯 Layer Responsibilities

**Use in:**

- ✅ Server Actions (`packages/supabase-data/`)
- ✅ Repositories (`packages/supabase-data/`)
- ✅ Edge Functions (`supabase/functions/`)

**Do NOT use in:**

- ❌ UI Components (`apps/web/`)
- ❌ Client Components
- ❌ Pages

## 📖 Full Docs

[Logging Architecture](../../docs/architecture/logging.md)  
[GR-005](../../docs/standards/rules/no-console-logging.md)

---

**For AI Agents:** Always use logging in Server Actions and business logic.
NEVER use console.log.
