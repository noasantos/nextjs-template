# Knip - Dead Code Detection

## What It Does

Knip is a dead code detection tool that finds:

- **Unused dependencies** - Packages listed in `package.json` but not imported
  in your code
- **Unused exports** - Functions, classes, types, and variables that are
  exported but never imported elsewhere
- **Unused files** - TypeScript/JavaScript files that aren't imported anywhere
- **Unresolved imports** - Import statements that reference non-existent modules
- **Duplicate exports** - Same identifier exported multiple times

## Why It Matters for AI-Assisted Development

Dead code accumulation is a common side effect of AI-assisted development:

1. **Refactoring residue** - AI often creates new implementations without
   cleaning up old code
2. **Over-generation** - AI may generate utility functions or components that
   never get used
3. **Dependency creep** - Unused packages accumulate as experiments are
   abandoned
4. **Export pollution** - AI tends to over-export "just in case" rather than
   following minimal exposure principles

Knip helps maintain code quality by:

- Keeping the codebase lean and understandable
- Reducing cognitive load for both humans and AI
- Preventing accumulation of technical debt
- Ensuring dependencies are intentional and necessary

## How to Run It

### Manual Execution

```bash
# Production mode (recommended - checks only production dependencies)
pnpm knip --production

# Include development dependencies
pnpm knip

# Watch mode for continuous checking
pnpm knip --watch
```

### Automated Checks

Knip runs automatically on `pre-push` via lefthook. The hook is configured to:

- Run in production mode
- Not block pushes (uses `--no-exit-code || true`)
- Report issues for review

## Configuration

Knip is configured in `knip.config.ts` at the repository root:

```typescript
import type { KnipConfig } from "knip"

export default {
  ignoreFiles: ["**/generated/**"],
  ignoreDependencies: ["lefthook", "turbo", "supabase"],
  ignoreExportsUsedInFile: true,
  workspaces: {
    "apps/*": {
      entry: ["app/**/{page,layout,route}.tsx"],
      project: ["src/**/*.{ts,tsx}"],
    },
    "packages/*": {
      entry: ["src/index.ts"],
      project: ["src/**/*.{ts,tsx}"],
    },
  },
} satisfies KnipConfig
```

### Key Configuration Options

- **workspaces** - Defines entry points and project files for each workspace
- **ignoreFiles** - Glob patterns for files to exclude from "unused files"
  reports
- **ignoreDependencies** - Package names to exclude from dependency checks
- **ignoreExportsUsedInFile** - Don't report exports that are used within the
  same file
- **ignore** - General ignore patterns for all issue types

## Common Violations and How to Fix Them

### Unused Dependencies

**Report:**

```
Unused dependencies (3)
lodash    package.json
moment    package.json
```

**Fix:**

1. Verify the dependency isn't used anywhere (search imports)
2. If truly unused: `pnpm remove <package-name>`
3. If used but not detected: check if it's a transitive dependency or needs type
   definitions

### Unused Exports

**Report:**

```
Unused exports (5)
src/utils/helpers.ts:15:14 - unused export 'formatDate'
src/components/Button.tsx:8:14 - unused export 'ButtonProps'
```

**Fix:**

1. Check if the export is used externally (other packages, apps)
2. If internal only: remove the `export` keyword
3. If truly unused: delete the export or the entire function/type
4. Consider if it's a public API that should be documented

### Unused Files

**Report:**

```
Unused files (12)
src/components/OldComponent.tsx
src/utils/deprecated-helpers.ts
```

**Fix:**

1. Verify the file isn't dynamically imported
2. Check if it's an entry point (page, route, layout)
3. If truly unused: delete the file
4. If it should be used: import it somewhere or add to entry patterns

### Unresolved Imports

**Report:**

```
Unresolved imports (2)
apps/example/app/page.tsx:5:20 - unresolved import '@/components/Missing'
src/utils.ts:3:15 - unresolved import 'non-existent-package'
```

**Fix:**

1. Check for typos in the import path
2. Verify the file exists at the specified location
3. Install missing packages
4. Check TypeScript path mappings in `tsconfig.json`

## Production Mode

Always run Knip in production mode (`--production`) for CI/CD and pre-push
hooks. This:

- Only checks production dependencies
- Ignores devDependencies used only in tests/scripts
- Matches the production build environment
- Reduces false positives

## Integration with Other Tools

Knip complements other quality tools in this repository:

- **Oxlint** - Catches code quality issues and bugs
- **TypeScript** - Catches type errors
- **dependency-cruiser** - Enforces architectural boundaries
- **Knip** - Removes dead code and unused dependencies

## Troubleshooting

### False Positives

If Knip reports something as unused but it's actually used:

1. **Dynamic imports** - Add the file to entry patterns
2. **Type-only imports** - Ensure `ignoreExportsUsedInFile` is enabled
3. **Build artifacts** - Add to `ignoreFiles` patterns
4. **Tooling dependencies** - Add to `ignoreDependencies`

### Missing Issues

If you know there's dead code but Knip doesn't report it:

1. Check that the file is included in `project` patterns
2. Verify entry points are correctly configured
3. Ensure `--production` flag matches your use case
4. Check if the code is actually referenced somewhere

## Best Practices

1. **Run regularly** - Don't let dead code accumulate
2. **Fix immediately** - Remove unused code when you see it
3. **Be conservative with exports** - Only export what's needed
4. **Review dependencies** - Periodically audit package.json
5. **Use production mode** - Matches real-world usage

## Resources

- [Knip Documentation](https://knip.dev/)
- [Knip GitHub Repository](https://github.com/webpro-nl/knip)
- [Production Mode Guide](https://knip.dev/features/production-mode)
- [Monorepos and Workspaces](https://knip.dev/features/monorepos-and-workspaces)
