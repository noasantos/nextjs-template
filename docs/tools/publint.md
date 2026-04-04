# publint

## What It Does

publint is a linter for published npm packages. It checks your package for
common issues that affect package consumers:

- **Missing exports**: Exports defined in package.json that don't exist
- **Missing files**: Files referenced in package.json that aren't included
- **Incorrect file extensions**: Using .js instead of .mjs/.cjs when needed
- **Missing peer dependencies**: Dependencies used but not declared
- **Incorrect main/module/exports**: Misconfigured entry points
- **Missing license**: Package missing license field
- **Deprecated fields**: Using deprecated package.json fields

## Why It Matters for AI-Assisted Development

When working with AI coding assistants in a monorepo with shared packages:

1. **Prevents broken packages**: AI may misconfigure package.json exports
2. **Ensures consistency**: Enforces consistent package structure
3. **Better DX for consumers**: Packages work correctly when imported
4. **Catches configuration errors**: AI might miss subtle package.json issues
5. **Monorepo hygiene**: Critical for workspace packages

## How to Run It

### Manual Execution

```bash
# Install publint globally
pnpm add -D publint

# Run against a specific package
pnpm publint packages/ui

# Run against all workspace packages
pnpm -r publint

# Run with verbose output
pnpm publint packages/ui --verbose
```

### Automated Execution

Add to CI/CD pipeline or pre-push hooks:

```yaml
# lefthook.yml (example)
pre-push:
  commands:
    publint:
      run: pnpm -r publint || true
```

## Common Issues and How to Fix Them

### 1. Missing Exports

**publint Output:**

```
publint publish check found issues:
- Missing export: ./button (exported in package.json but file not found)
```

**Fix:**

```json
// package.json
{
  "exports": {
    "./button": "./src/button.ts" // ✅ Ensure file exists
  }
}
```

Or remove the export if it doesn't exist:

```json
{
  "exports": {
    // Remove non-existent exports
  }
}
```

### 2. Missing Files

**publint Output:**

```
- Missing file: ./dist/index.js (referenced in main but not found)
```

**Fix:**

```json
// package.json
{
  "main": "./dist/index.js" // ✅ Ensure build runs before publish
}
```

Run build before publishing:

```bash
pnpm build
pnpm publint
```

### 3. Incorrect File Extensions

**publint Output:**

```
- Incorrect extension: ./index.js should be ./index.mjs for ESM
```

**Fix:**

```json
// package.json
{
  "type": "module",
  "main": "./index.mjs" // ✅ Use .mjs for ESM
}
```

### 4. Missing Peer Dependencies

**publint Output:**

```
- Missing peer dependency: react (used in exports but not declared)
```

**Fix:**

```json
// package.json
{
  "peerDependencies": {
    "react": "^19.0.0" // ✅ Add missing peer dependency
  }
}
```

### 5. Missing License

**publint Output:**

```
- Missing license: No license field in package.json
```

**Fix:**

```json
// package.json
{
  "license": "MIT" // ✅ Add license
}
```

## Configuration for Monorepo

### Workspace Package Example

```json
// packages/ui/package.json
{
  "name": "@workspace/ui",
  "version": "0.0.1",
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "exports": {
    ".": "./src/index.ts",
    "./components": "./src/components/index.ts"
  },
  "peerDependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "license": "MIT",
  "files": ["src", "dist"]
}
```

### Build Before Publish

```json
// package.json
{
  "scripts": {
    "build": "tsc",
    "prepublishOnly": "pnpm build && pnpm publint"
  }
}
```

## Integration with AI-Assisted Development

### When AI Creates New Packages

1. **Run publint**: Always run publint after AI scaffolds a package
2. **Check exports**: Verify exports are correctly configured
3. **Verify peer deps**: Ensure peer dependencies are declared
4. **Add license**: Make sure license field is present

### When AI Updates package.json

1. **Validate changes**: Run publint to catch configuration errors
2. **Check exports**: Ensure new exports point to existing files
3. **Verify dependencies**: Check that dependencies are correctly declared

## Best Practices

1. **Run publint before publishing**: Always validate before npm publish
2. **Add to prepublishOnly**: Automate with npm lifecycle scripts
3. **Use with TypeScript**: Ensure types are exported correctly
4. **Check in CI**: Add publint to CI pipeline
5. **Fix issues immediately**: Don't ignore publint warnings

## Example CI Configuration

```yaml
# .github/workflows/publint.yml
name: Publint

on:
  pull_request:
    branches: [main]

jobs:
  publint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v2
        with:
          version: 10

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: "pnpm"

      - run: pnpm install
      - run: pnpm build
      - run: pnpm -r publint
```

## Related Tools

- **arethetypeswrong**: Type checking for published packages
- **npm-packlist**: Check what files will be included in package
- **changesets**: Version and publish management for monorepos

## References

- [publint GitHub Repository](https://github.com/publint/publint)
- [npm package.json Documentation](https://docs.npmjs.com/cli/v10/configuring-npm/package-json)
- [TypeScript Package Publishing Guide](https://www.typescriptlang.org/docs/handbook/declaration-files/publishing.html)
