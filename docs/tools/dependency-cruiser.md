# Dependency Cruiser

## What It Does

Dependency Cruiser enforces architectural boundaries in the codebase by
analyzing and validating module dependencies. It prevents:

- **Cross-app imports**: Apps cannot import from other apps in the monorepo
- **Server-to-client leaks**: Server-only code (database, Supabase admin, server
  utilities) cannot be imported into client components
- **Barrel imports**: Direct imports to `index.ts` files are blocked to
  encourage explicit imports
- **Circular dependencies**: Prevents modules from depending on each other in
  cycles

## Why It Matters for AI-Assisted Development

When working with AI coding assistants, architectural boundaries can be
accidentally violated through auto-complete or suggested imports. Dependency
Cruiser acts as an automated guardian that:

1. **Catches mistakes early**: Prevents architectural violations before they
   reach code review
2. **Maintains separation of concerns**: Ensures server and client code remain
   properly isolated
3. **Enforces explicit imports**: Makes dependencies clear and traceable
4. **Prevents subtle bugs**: Circular dependencies and server code leaks can
   cause hard-to-debug runtime issues

## How to Run It

### Manual Execution

Template apps use `apps/<app>/app/` (no `src/`). Run depcruise on **app** roots
and packages:

```bash
# Run on all app routers + packages (matches lefthook pre-push)
pnpm depcruise apps/*/app packages/*/src --config .dependency-cruiser.cjs

# Run on one app
pnpm depcruise apps/example/app --config .dependency-cruiser.cjs

# Generate visual dependency graph (optional)
pnpm depcruise apps/*/app packages/*/src --config .dependency-cruiser.cjs --output-type dot | dot -T svg > dependency-graph.svg
```

### Automated Execution

Dependency Cruiser runs automatically on `git push` as part of the pre-push hook
configured in `lefthook.yml`.

## Common Violations and How to Fix Them

### 1. Cross-App Import

**Error**: `apps/web/app cannot import apps/example/app`

**Fix**: Move shared code to a package in `packages/` and import from there
instead.

```typescript
// ❌ Wrong
import { utils } from "apps/example/src/utils"

// ✅ Correct
import { utils } from "@repo/utils"
```

### 2. Server-to-Client Import

**Error**: `client component imports server-only module`

**Fix**: Ensure server code is only used in server components or API routes. The
rule blocks imports of:

- `server-only` package
- Files matching `(server|database|supabase-admin)` patterns
- Next.js server modules

```typescript
// ❌ Wrong - in client component
import { db } from "@/lib/database"
import "server-only"

// ✅ Correct - use only in server components
// Move database logic to server action or API route
// Files containing 'server' in path are allowed (e.g., app/[locale]/server/action.ts)
```

**Note**: If you're seeing violations in test files (`.test.ts`) or legitimate
server code, the rule uses path matching. Files with 'server' in the path are
considered server code and allowed to import server-only modules.

### 3. Barrel Import

**Error**: `import to index.ts is not allowed`

**Fix**: Import directly from the specific file instead of through the barrel.

```typescript
// ❌ Wrong
import { foo, bar } from "@/utils"

// ✅ Correct
import { foo } from "@/utils/foo"
import { bar } from "@/utils/bar"
```

### 4. Circular Dependency

**Error**: `module A imports module B which imports module A`

**Fix**: Extract shared code to a third module or restructure dependencies.

```typescript
// ❌ Wrong
// module-a.ts imports module-b.ts
// module-b.ts imports module-a.ts

// ✅ Correct
// Extract shared logic to module-c.ts
// Both module-a.ts and module-b.ts import from module-c.ts
```

## Configuration

The configuration file `.dependency-cruiser.cjs` defines all rules. See the file
for detailed rule definitions and can be customized as the architecture evolves.

## Current Violations

As of the initial setup, there are 41 server-to-client violations detected in
the codebase. These are primarily:

- Server actions importing `server-only` or Next.js server modules
- Auth utilities using server-side code
- Logging packages with server sinks

These violations should be addressed by:

1. Moving server-only logic to properly named server files (containing 'server'
   in the path)
2. Using server actions for data mutations
3. Separating client and server logging utilities

## Integration with Other Tools

- **Lefthook**: Runs on pre-push to catch violations before code leaves your
  machine
- **CI/CD**: Can be added to CI pipelines for additional validation
- **VS Code**: Optional editor integration available via dependency-cruiser VS
  Code extension
