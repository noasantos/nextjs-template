> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/edge-function-template.mdc`](../../../.cursor/rules/edge-function-template.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# ⚡ Edge Function Template Mandatory

**This is a CURSOR-SPECIFIC rule file.**

**Full documentation:**
[docs/standards/rules/edge-function-template.md](../../docs/standards/rules/edge-function-template.md)

## Rule for Cursor

Cursor MUST enforce Edge Function template:

- **NEVER** suggest manual Edge Function creation
- **ALWAYS** use `pnpm edge:new -- <name>`
- **FAIL** if giant index.ts detected (> 50 lines)

## Quick Reference

```bash
# ✅ CORRECT - Use template
pnpm edge:new -- process-payment

# ❌ FORBIDDEN - Manual creation
mkdir supabase/functions/process-payment
```

## File Responsibilities

| File            | Responsibility   | Max Lines |
| --------------- | ---------------- | --------- |
| `index.ts`      | Request/Response | 50        |
| `handler.ts`    | Business logic   | 200       |
| `types.ts`      | Type definitions | 100       |
| `validation.ts` | Validation       | 100       |

## AI Agent Instructions

When creating Edge Functions:

1. RUN `pnpm edge:new -- <name>`
2. FOLLOW SRP (Single Responsibility Principle)
3. USE `_shared/` utilities
4. KEEP index.ts thin (< 50 lines)

---

**Rule ID:** EDGE-FUNCTION-TEMPLATE  
**Severity:** CRITICAL  
**Full Docs:**
[docs/standards/rules/edge-function-template.md](../../docs/standards/rules/edge-function-template.md)
