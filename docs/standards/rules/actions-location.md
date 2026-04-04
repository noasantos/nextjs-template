> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/actions-location.mdc`](../../../.cursor/rules/actions-location.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# Server Actions Location Rule

## Architecture

**Server Actions MUST live in:** `packages/supabase-data/src/actions/{module}/`

**Server Actions MUST NOT live in:** `apps/*/actions/` or `apps/*/lib/`

### Why

| Layer                     | Responsibility                       | Can Define Actions?       |
| ------------------------- | ------------------------------------ | ------------------------- |
| `apps/*/`                 | UI composition, routing, view-models | ❌ NO                     |
| `packages/supabase-data/` | Business logic, data access          | ✅ YES                    |
| `packages/supabase-auth/` | Auth primitives                      | ❌ NO (only auth helpers) |
| `packages/logging/`       | Logging infrastructure               | ❌ NO                     |

### Correct Structure

```
packages/supabase-data/src/actions/
├── profiles/
│   └── get-profile-by-user-id.ts      ✅
├── user-roles/
│   └── sync-user-roles.ts             ✅
└── example/
    └── create-example-action.ts       ✅

apps/example/
├── app/
│   └── page.tsx                        ✅ (consumes actions)
├── components/
│   └── form.tsx                        ✅ (calls actions)
└── actions/                            ❌ FORBIDDEN!
    └── example.ts                      ❌ DELETE THIS!
```

## Import Pattern

### In Apps (Correct)

```typescript
// ✅ CORRECT - Import from package
import { createExampleAction } from '@workspace/supabase-data/actions/example/create-example-action'

// Page server component
export default async function Page() {
  const result = await createExampleAction({ title: 'Test' })
  return <div>...</div>
}
```

### In Apps (Wrong)

```typescript
// ❌ WRONG - App-local action
import { createExampleAction } from './actions/example'

// ❌ WRONG - Creating action in app
export const myAction = authActionClient
  .inputSchema(...)
  .action(...)
```

## What Apps CAN Define

Apps are allowed to define ONLY:

1. **Page-specific helpers** (URL/state glue):

   ```typescript
   // ✅ OK - App-specific orchestration
   async function handleCreateAndRedirect() {
     const result = await createExampleAction(input)
     if (result.success) {
       router.push(`/items/${result.data.id}`)
       toast.success("Created!")
     }
   }
   ```

2. **View-model shaping**:

   ```typescript
   // ✅ OK - Transforming data for UI
   function formatForDisplay(data: Data) {
     return { ... }
   }
   ```

3. **Local interaction handlers**:
   ```typescript
   // ✅ OK - Client-side logic
   function handleClick() {
     // ...
   }
   ```

## What Apps CANNOT Define

Apps are FORBIDDEN from defining:

1. **Server Actions** ❌
2. **Database abstraction layers** (`lib/db/actions/*`) ❌
3. **Repositories** (`lib/repositories/*`) ❌
4. **Wrappers that just forward to packages** ❌

## If You Need a New Action

1. Create in `packages/supabase-data/src/actions/{module}/`
2. Use `authActionClient` or `actionClient`
3. Define input schema with Zod v4
4. Return typed result
5. Import from app

## Related Rules

- [`.cursor/rules/zod-v4-syntax.mdc`](zod-v4-syntax.mdc) - Zod v4 patterns
- [`.cursor/rules/use-safe-actions.mdc`](use-safe-actions.mdc) -
  next-safe-action patterns
- [`docs/architecture/system.md`](/docs/architecture/system.md) - Architecture
  overview
- [`docs/architecture/backend.md`](/docs/architecture/backend.md) - Backend
  standards

## Enforcement

- **Pre-commit:** dependency-cruiser blocks cross-layer violations
- **Code review:** Reject PRs with app-local actions
- **AI agents:** Never suggest creating actions in apps/
