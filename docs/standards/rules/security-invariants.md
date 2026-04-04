> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/security-invariants.mdc`](../../../.cursor/rules/security-invariants.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# 🔐 Security Invariants

**This is a CURSOR-SPECIFIC rule file.**

**Full documentation:**
[docs/standards/rules/security-invariants.md](../../docs/standards/rules/security-invariants.md)

## Rule for Cursor

Cursor MUST enforce these security invariants:

1. **ALWAYS** use `getClaims()` for auth (NOT `getUser()`)
2. **ALWAYS** sanitize headers in proxy.ts
3. **ALWAYS** use dynamic CSP with nonce
4. **NEVER** use `console.log` (use `logServerEvent`)

## Quick Reference

```typescript
// ✅ getClaims() - JWKS cached (fast)
const claims = await getClaims()

// ❌ getUser() - DB call (slow)
const user = await getUser()

// ✅ Header sanitization
const sanitizedHeaders = new Headers(request.headers)
sanitizedHeaders.delete("x-middleware-subrequest")
```

## Enforcement

- `pnpm check:security-smells` - Automated scan
- Pre-commit hook - Blocks violations
- Cursor should auto-fix security issues

---

**Rule ID:** SECURITY-INVARIANTS  
**Severity:** CRITICAL  
**Full Docs:**
[docs/standards/rules/security-invariants.md](../../docs/standards/rules/security-invariants.md)
