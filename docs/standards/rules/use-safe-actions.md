> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/use-safe-actions.mdc`](../../../.cursor/rules/use-safe-actions.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

When creating Server Actions that require authentication:

- Use `authActionClient` from `@/lib/safe-action`
- Never manually call getClaims() in each action
- Let the middleware handle auth checks
- Access userId via ctx.userId

## Examples

### Correct Usage

```typescript
"use server"

import { authActionClient } from "@/lib/safe-action"
import { z } from "zod"

export const createTask = authActionClient
  .schema(z.object({ title: z.string() }))
  .action(async ({ parsedInput, ctx }) => {
    // ctx.userId is available from auth middleware
    const { title } = parsedInput

    // Use ctx.userId for ownership
    return await db.task.create({
      data: {
        title,
        userId: ctx.userId,
      },
    })
  })
```

### Incorrect Usage

```typescript
// ❌ Wrong - manually calling getClaims()
"use server"

import { getClaims } from "@workspace/supabase-auth/session"

export const createTask = async (title: string) => {
  const claims = await getClaims()
  if (!claims?.sub) throw new Error("Unauthorized")

  // This pattern is error-prone and verbose
}
```

## Related Rules

- [auth-invariants](./auth-invariants.mdc) - Auth pattern enforcement
- [security-invariants](./security-invariants.mdc) - Security best practices
