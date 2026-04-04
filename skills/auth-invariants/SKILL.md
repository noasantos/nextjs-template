---
name: auth-invariants
description: >-
  Enforces auth patterns: prefer getClaims() over getUser() per GR-004. Use when
  implementing authentication, session checks, or replacing getUser or
  getSession usage.
---

# Auth Invariants Skill

## Purpose

Enforce authentication patterns following GR-004 (Auth Invariants): getClaims()
primary, getUser() secondary.

## When to Trigger

Auto-trigger when user:

- Implements authentication
- Uses getUser() or getSession()
- Mentions "auth check" or "login"

## Skill Instructions

### **1. Performance Hierarchy**

```typescript
// ✅ PRIMARY - getClaims() (JWKS cached, <1ms, 0 network calls)
const claims = await getClaims()
const userId = claims.sub

// ⚠️ SECONDARY - getUser() (DB call, ~50ms, 1 network call)
const user = await getUser()
const email = user.email

// ❌ DEPRECATED - getSession() (only for tokens)
const session = await getSession()
```

### **2. When to Use Each**

**Use getClaims() for:**

- ✅ Simple auth checks
- ✅ User ID
- ✅ Role checks
- ✅ Performance-critical paths

**Use getUser() ONLY for:**

- ✅ Full user profile
- ✅ Email confirmation
- ✅ Last sign-in timestamp
- ✅ DB metadata

**Use getSession() ONLY for:**

- ✅ Session expiry
- ✅ Refresh token
- ✅ Provider token

### **3. Enforce Rules**

- ✅ **GR-004**: getClaims() is primary
- ✅ **Performance**: Prefer cached calls
- ✅ **Logging**: Log auth events

## Examples

### **User Request**

```
"Check if user is authenticated"
```

### **Skill Response**

```typescript
// ✅ CORRECT - getClaims() is primary
import { getClaims } from "@workspace/supabase-auth/session"

const claims = await getClaims()
if (!claims?.sub) {
  throw new Error("Unauthorized")
}
const userId = claims.sub

// ❌ WRONG - getUser() for simple check (slow!)
const user = await getUser() // Makes DB call unnecessarily
```

## Related Skills

- **[security-check](../security-check/)** - Security scan
- **[logging-required](../logging-required/)** - Log auth events
- **[server-action-template](../server-action-template/)** - Auth in actions

## References

- **[GR-004: Auth Invariants](../../docs/standards/rules/auth-invariants.md)**
- **[Security Invariants](../../docs/standards/rules/security-invariants.md)**
- **[Session Management](../../docs/architecture/auth.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
