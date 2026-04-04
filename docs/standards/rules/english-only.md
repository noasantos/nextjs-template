> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/english-only.mdc`](../../../.cursor/rules/english-only.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# 🇬🇧 English Only

**This is a CURSOR-SPECIFIC rule file.**

**Full documentation:**
[docs/standards/rules/english-only.md](../../docs/standards/rules/english-only.md)

## Rule for Cursor

Cursor MUST enforce English-only rule:

- **NEVER** suggest non-English comments
- **ALWAYS** write code/comments in English
- **AUTO-FIX** non-English to English

## Quick Reference

```typescript
// ✅ CORRECT - English
// Calculate user's subscription expiry date
const expiryDate = calculateExpiryDate(startDate, duration)

// ❌ FORBIDDEN - Portuguese
// Calcular data de expiração do usuário
const expiryDate = calculateExpiryDate(startDate, duration)
```

## Exception

UI text can be translated via `next-intl` messages files.

---

**Rule ID:** ENGLISH-ONLY  
**Severity:** REQUIRED  
**Full Docs:**
[docs/standards/rules/english-only.md](../../docs/standards/rules/english-only.md)
