---
name: security-check
description: >-
  Scans for security smells per GR-003. Use when committing auth code, Server
  Actions, or Edge Functions.
---

# Security Check Skill

## Purpose

Scan code for security issues following GR-003 (Security Invariants).

## When to Trigger

Auto-trigger when user:

- Commits code
- Mentions "security check" or "scan"
- Creates Server Action or Edge Function

## Skill Instructions

### **1. Scan For**

```typescript
// ❌ FORBIDDEN - Hardcoded credentials
const key = "sk_live_abc123"

// ❌ FORBIDDEN - NEXT_PUBLIC secrets
const NEXT_PUBLIC_SECRET_KEY = "secret"

// ❌ FORBIDDEN - console.log sensitive data
console.log("token:", token)

// ❌ FORBIDDEN - getUser() for auth (slow)
const user = await getUser()

// ❌ FORBIDDEN - Missing header sanitization
export async function proxy(request: NextRequest) {
  // Missing: sanitizedHeaders.delete("x-middleware-subrequest")
}
```

### **2. Auto-Fix**

```typescript
// ✅ CORRECT - Environment variables
const key = process.env.STRIPE_SECRET_KEY

// ✅ CORRECT - No public secrets
// Use server-only env vars

// ✅ CORRECT - Structured logging
await logServerEvent({
  /* ... */
})

// ✅ CORRECT - getClaims() for auth
const claims = await getClaims()

// ✅ CORRECT - Header sanitization
const sanitizedHeaders = new Headers(request.headers)
sanitizedHeaders.delete("x-middleware-subrequest")
```

### **3. Enforce Rules**

- ✅ **GR-003**: Security invariants
- ✅ **No secrets**: Use environment variables
- ✅ **No console**: Use structured logging
- ✅ **Header sanitization**: CVE-2025-29927 protection

## Examples

### **User Request**

```
"Check this code for security issues"
```

### **Skill Response**

1. **SCAN for:**
   - Hardcoded credentials
   - NEXT_PUBLIC secrets
   - console.log sensitive data
   - Missing header sanitization

2. **AUTO-FIX:**
   - Replace with env vars
   - Use logServerEvent
   - Add header sanitization

3. **REMIND:**
   - "Run pnpm check:security-smells"
   - "Never commit .env files"

## Related Skills

- **[logging-required](../logging-required/)** - Structured logging
- **[auth-invariants](../auth-invariants/)** - Auth patterns
- **[server-action-template](../server-action-template/)** - Secure actions

## References

- **[GR-003: Security Invariants](../../docs/standards/rules/security-invariants.md)**
- **[Security Guide](../../docs/guides/security.md)**
- **[CVE-2025-29927](../../docs/architecture/proxy-pattern.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
