> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/proxy-not-middleware.mdc`](../../../.cursor/rules/proxy-not-middleware.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# 🚨 CRITICAL: Next.js 16 Uses proxy.ts NOT middleware.ts

**This is a CURSOR-SPECIFIC rule file.**

**Full documentation:**
[docs/standards/rules/proxy-not-middleware.md](../../docs/standards/rules/proxy-not-middleware.md)

## Rule for Cursor

Cursor MUST enforce this rule:

- **NEVER** suggest creating `middleware.ts`
- **ALWAYS** create `proxy.ts` for Next.js 16
- **FAIL** if `middleware.ts` is detected

## Quick Reference

```typescript
// ✅ CORRECT - apps/web/proxy.ts
export default async function proxy(request: NextRequest) {
  return await updateSession(request)
}

// ❌ FORBIDDEN - apps/web/middleware.ts
```

## Enforcement

- Pre-commit hook checks for `middleware.ts`
- CI fails if `middleware.ts` found
- Cursor should auto-fix to `proxy.ts`

---

**Rule ID:** PROXY-NOT-MIDDLEWARE  
**Severity:** CRITICAL  
**Full Docs:**
[docs/standards/rules/proxy-not-middleware.md](../../docs/standards/rules/proxy-not-middleware.md)
