> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/zero-barrel-policy.mdc`](../../../.cursor/rules/zero-barrel-policy.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# 🚫 Zero-Barrel Policy

**This is a CURSOR-SPECIFIC rule file.**

**Full documentation:**
[docs/standards/rules/zero-barrel-policy.md](../../docs/standards/rules/zero-barrel-policy.md)

## Rule for Cursor

Cursor MUST enforce zero-barrel policy:

- **NEVER** suggest barrel imports (`@workspace/ui`)
- **ALWAYS** use subpath imports (`@workspace/ui/components/button`)
- **FAIL** if barrel imports detected

## Quick Reference

```typescript
// ✅ CORRECT - Explicit subpath
import { Button } from "@workspace/ui/components/button"

// ❌ FORBIDDEN - Barrel import
import { Button } from "@workspace/ui"
```

## Enforcement

- Oxlint `no-restricted-imports` (error)
- Pre-commit hook blocks violations
- Cursor should auto-fix to subpath imports

---

**Rule ID:** ZERO-BARREL  
**Severity:** ERROR  
**Full Docs:**
[docs/standards/rules/zero-barrel-policy.md](../../docs/standards/rules/zero-barrel-policy.md)
