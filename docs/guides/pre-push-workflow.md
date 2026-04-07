# Pre-Push Validation Workflow

**Critical requirement:** All pre-push hooks **MUST** pass before pushing to
remote.

## Why This Matters

Pre-push hooks enforce code quality, security, and architectural integrity.
Bypassing them risks:

- **Security vulnerabilities** reaching production
- **Architectural violations** (server-to-client leaks, cross-app imports)
- **Broken packages** with invalid exports
- **Type errors** causing runtime failures
- **Test failures** indicating regressions

## Pre-Push Hooks (in order)

The following checks run automatically on `git push`:

### 1. Type Check (`typecheck`)

```bash
pnpm typecheck
```

**What it does:** Runs TypeScript compiler in noEmit mode across all packages
and apps.

**Common failures:**

- Type mismatches
- Missing type definitions
- Incorrect generic parameters

**How to fix:** Run `pnpm typecheck` locally and fix reported errors.

### 2. Unit Tests (`test`)

```bash
pnpm test
```

**What it does:** Runs Vitest unit tests across all packages.

**Common failures:**

- Failing test assertions
- Snapshot mismatches
- Test setup errors

**How to fix:** Run `pnpm test` locally and fix failing tests.

### 3. Package Exports Validation (`publint`)

```bash
pnpm -r --filter './packages/*' exec publint
```

**What it does:** Validates that all package.json exports point to existing
files.

**Common failures:**

- Export paths that don't exist
- Missing config files referenced in exports

**How to fix:**

1. Ensure all files referenced in `package.json` → `exports` exist
2. Copy or create required config files
3. Remove unused export entries

**Example fix:**

```bash
# If package.json exports "./config/foo.json"
mkdir -p packages/my-package/config
cp config/foo.json packages/my-package/config/
```

### 4. Dead Code Detection (`knip`)

```bash
pnpm knip --production --no-exit-code
```

**What it does:** Finds unused dependencies, files, and exports.

**Common failures:**

- Unused dependencies
- Unreferenced files
- Unused exports

**How to fix:**

- Remove unused dependencies from package.json
- Delete unreferenced files
- Remove or use unused exports

### 5. Security Audit (`audit`)

```bash
pnpm audit --audit-level=high
```

**What it does:** Checks for known security vulnerabilities in dependencies.

**Common failures:**

- High/critical severity vulnerabilities
- Outdated packages with security issues

**How to fix:**

```bash
# Update vulnerable packages
pnpm update <package>@latest

# Or use pnpm overrides for transitive dependencies
# In package.json:
{
  "pnpm": {
    "overrides": {
      "vulnerable-package": ">=1.2.3"
    }
  }
}
```

### 6. Architectural Boundaries (`depcruise`)

```bash
pnpm depcruise apps/*/app packages/*/src --config .dependency-cruiser.cjs
```

**What it does:** Enforces architectural rules:

- No cross-app imports
- No server-to-client imports
- No barrel imports (index.ts)
- No circular dependencies

**Common failures:**

#### Server-to-Client Import

```
error no-server-to-client: packages/supabase-data/src/lib/auth/require-auth.ts → @workspace/logging/server
```

**Fix:** Add the path to `.dependency-cruiser.cjs` → `from.pathNot` pattern if
it's legitimately server-only code.

#### Cross-App Import

```
error no-cross-app-imports: apps/web/src cannot import apps/example/src
```

**Fix:** Move shared code to a package in `packages/` and import from there.

#### Barrel Import

```
error no-barrel-imports: import to index.ts is not allowed
```

**Fix:** Import directly from the specific file instead of through the barrel.

```typescript
// ❌ Wrong
import { foo } from "@/utils"

// ✅ Correct
import { foo } from "@/utils/foo"
```

#### Circular Dependency

```
error no-circular: module A → module B → module A
```

**Fix:** Extract shared code to a third module or restructure dependencies.

## Manual Pre-Push Checklist

Before pushing, run locally:

```bash
# Full pre-push validation
pnpm typecheck && pnpm test && pnpm audit --audit-level=high && pnpm depcruise apps/*/app packages/*/src --config .dependency-cruiser.cjs
```

## Bypassing Pre-Push (NOT RECOMMENDED)

**Only for emergencies** with explicit team approval:

```bash
git push origin main --no-verify
```

**⚠️ WARNING:** Bypassing hooks puts the codebase at risk. Always fix issues
properly instead.

## Troubleshooting

### "Tests pass locally but fail on push"

- Ensure you're running the same command: `pnpm test`
- Check for environment variable differences
- Clear cache: `pnpm test -- --clearCache`

### "Dependency Cruiser passes locally but fails on push"

- Ensure you're using the same config: `--config .dependency-cruiser.cjs`
- Check if new files were added but not committed
- Run on the same paths: `apps/*/app packages/*/src`

### "Publint fails with missing config files"

- Copy config files to package directory
- Ensure exports in package.json match actual file paths
- Example: `cp config/foo.json packages/my-package/config/`

### "Audit shows vulnerabilities"

- Update the vulnerable package: `pnpm update <package>@latest`
- For transitive dependencies, use `pnpm.overrides` in package.json
- If no fix exists, document the risk and timeline for resolution

## CI/CD Integration

These same checks run in CI on pull requests. Passing locally does not guarantee
CI will pass, but failing locally guarantees CI will fail.

## Related Documentation

- [Dependency Cruiser Guide](./tools/dependency-cruiser.md)
- [Testing Strategy](./architecture/testing.md)
- [Security Standards](./standards/rules/security-checklist.md)
- [Architecture Rules](./standards/rules/critical-architecture-rules.md)
