# @workspace/supabase-infra

Core Supabase infrastructure: types, clients, env.

## 🚨 CRITICAL

**Read before using:**

- [Supabase Setup](../../docs/guides/supabase-setup.md)
- [Security Invariants](../../docs/standards/rules/security-invariants.md)

## 📦 Exports

```typescript
// Types
import type { Database } from "@workspace/supabase-infra/types"

// Environment
import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import { getSupabaseServerEnv } from "@workspace/supabase-infra/env/server"
import {
  getPublicSiteUrl,
  isRobotsAllowIndexing,
} from "@workspace/supabase-infra/env/site"

// Clients
import { createAdminClient } from "@workspace/supabase-infra/clients/admin"
import { createRealtimeClient } from "@workspace/supabase-infra/clients/realtime"
```

## 🔒 Security

**Admin client bypasses RLS - server only!**

```typescript
// ✅ Server-side only
const admin = createAdminClient()

// ❌ NEVER in browser
```

## 📖 Full Docs

[Supabase Setup](../../docs/guides/supabase-setup.md)  
[Security](../../docs/standards/rules/security-invariants.md)

---

**For AI Agents:** This is the FOUNDATION. All Supabase clients come from here.
NEVER create clients directly.
