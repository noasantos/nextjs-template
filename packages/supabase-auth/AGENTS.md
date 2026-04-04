# @workspace/supabase-auth

Authentication, session, authorization guards.

## 🚨 CRITICAL

**Read before using:**

- [Auth Invariants](../../docs/standards/rules/auth-invariants.md)
- [Auth Architecture](../../docs/architecture/auth.md)

## 🎯 Auth Hierarchy

```typescript
// ✅ PRIMARY - getClaims() (fast, JWKS cached)
const claims = await getClaims()

// ⚠️ SECONDARY - getUser() (slow, DB call)
const user = await getUser()

// ❌ DEPRECATED - getSession() (legacy only)
const session = await getSession()
```

## 📦 Exports

```typescript
// Browser
import { createBrowserAuthClient } from "@workspace/supabase-auth/browser"

// Server
import { createServerAuthClient } from "@workspace/supabase-auth/server"

// Next.js App Router — shared GET handlers (mount thin `route.ts` in each app)
import { authConfirmGet } from "@workspace/supabase-auth/server/route-handlers/auth-confirm-get"
import { callbackGet } from "@workspace/supabase-auth/server/route-handlers/callback-get"
import { logoutGet } from "@workspace/supabase-auth/server/route-handlers/logout-get"

// Session
import { getClaims, getUser } from "@workspace/supabase-auth/session"

// Shared (URLs, robots, forms, search params)
import {
  AUTH_ROUTE_PATH_PREFIXES,
  buildAuthRobotsDisallowPaths,
} from "@workspace/supabase-auth/shared/auth-route-paths"
import { resolveAuthSearchParams } from "@workspace/supabase-auth/shared/resolve-auth-search-params"
import { createAuthFormSchemas } from "@workspace/supabase-auth/shared/auth-form-schemas"
import {
  buildAuthContinueUrl,
  getContinueDecision,
} from "@workspace/supabase-auth/shared/app-destination"

// Proxy (Next.js 16)
import { updateSession } from "@workspace/supabase-auth/proxy"
```

## 📖 Full Docs

[Auth Invariants](../../docs/standards/rules/auth-invariants.md)  
[Auth Architecture](../../docs/architecture/auth.md)

---

**For AI Agents:** ALWAYS use getClaims() for auth. NEVER use getUser() for
simple checks.
