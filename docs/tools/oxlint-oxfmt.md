# Oxlint + Oxfmt Configuration

This template uses **Oxlint** and **Oxfmt** for linting and formatting — **NOT
ESLint or Prettier**.

**Why:** Oxlint is **50-100x faster** than ESLint, written in Rust, and provides
native TypeScript support without plugins.

---

## Configuration Files

### `.oxlintrc.json` (Root Only)

**Location:** Repository root

**Format:** JSON (NOT TypeScript/JavaScript)

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "env": {
    "browser": true,
    "node": true,
    "es2024": true
  },
  "globals": {
    "React": "readonly",
    "process": "readonly"
  },
  "plugins": ["typescript", "react", "jsx-a11y", "import", "nextjs", "unicorn"],
  "categories": {
    "correctness": "error",
    "suspicious": "warn",
    "perf": "warn",
    "restriction": "warn",
    "nursery": "off"
  },
  "options": {
    "typeAware": false
  },
  "settings": {
    "next": {
      "rootDir": ["apps/*/", "packages/*/"]
    }
  },
  "rules": {
    "no-console": "error",
    "no-debugger": "error",
    "typescript/no-explicit-any": "error",
    "typescript/no-non-null-assertion": "error"
  }
}
```

**Key Points:**

- ✅ **Categories in `"categories"` key** (NOT in `"rules"`)
- ✅ **TypeScript prefix:** `typescript/` (NOT `@typescript-eslint/`)
- ✅ **Schema:** Local path `./node_modules/oxlint/configuration_schema.json`
- ✅ **Plugins:** Native Rust plugins declared explicitly
- ✅ **No ESLint carryovers:** No `import/resolver` in settings

### `packages/ui` (vendored shadcn)

Root **`.oxlintrc.json`** ignores
**`packages/ui/**`** (`ignorePatterns`). Oxlint does not run on that tree, so you will not get hundreds of warnings from Radix/shadcn patterns (multi-component files, default exports, JSX in `.tsx`,
etc.).

**Policy (aligns with GR-001 / `@workspace/ui` immutable):**

- Do **not** edit `packages/ui/src/**` (or other UI package files) to “fix” lint
  — that package is treated as vendored CLI output.
- Product fixes belong in **`@workspace/brand`** or **`apps/<app>/`**.
- **Oxfmt** may still format files under `packages/ui` when you run
  `pnpm format` at the repo root (formatter ignores are separate from Oxlint);
  prefer leaving UI formatting to humans or the shadcn CLI unless you are
  intentionally syncing style.

If you add a **new** path that must stay vendored and lint-free, extend
`ignorePatterns` in `.oxlintrc.json` and document it here.

### `.oxfmtrc.json` (root only)

**Location:** repository root.

Oxfmt searches upward and uses the **first** config found, in this order:
`.oxfmtrc.json` → `.oxfmtrc.jsonc` → `oxfmt.config.ts`
([configuration](https://oxc.rs/docs/guide/usage/formatter/config)). If
`.oxfmtrc.json` exists, a sibling `oxfmt.config.ts` is **not** loaded—keep
**one** canonical file to avoid dead configuration.

Use the JSON schema for valid keys
(`./node_modules/oxfmt/configuration_schema.json`). Do **not** use Prettier-only
fields (`plugins`, `importOrder` from prettier plugins, etc.); use Oxfmt’s
`sortImports`, `sortTailwindcss`, `ignorePatterns`, and `overrides` instead.

The repo’s committed `.oxfmtrc.json` includes line width, `semi: false`, import
sorting (`@workspace/` via `internalPattern`), Tailwind class sorting for
`cn`/`cva`, and ignores for generated DB types.

---

## Commands

### Local Development

```bash
# Lint entire repo
pnpm lint

# Format entire repo
pnpm format

# Check format without writing (CI)
pnpm format:check

# Lint only staged files (pre-commit)
pnpm lint:staged
```

### Turbo Commands

```bash
# Lint specific package
pnpm turbo lint --filter=@workspace/supabase-data

# Lint specific app
pnpm turbo lint --filter=example
```

---

## Migration from ESLint

If migrating from ESLint, use the official migration tool:

```bash
# Automatic migration
npx @oxlint/migrate

# With type-aware rules
npx @oxlint/migrate --type-aware

# With JavaScript plugins (if needed)
npx @oxlint/migrate --js-plugins
```

**What Gets Migrated:**

- Rule severities and options
- File/path overrides
- Globals and env settings
- Import resolvers

**What Does NOT Migrate:**

- ESLint-specific plugins without Oxlint equivalents
- Custom ESLint rules
- Flat config format (`.js`/`.mjs`)

---

## Rule Categories

Oxlint organizes rules into categories:

| Category      | Purpose                        | Default |
| ------------- | ------------------------------ | ------- |
| `correctness` | Code that will definitely fail | `error` |
| `suspicious`  | Likely bugs or anti-patterns   | `warn`  |
| `perf`        | Performance optimizations      | `warn`  |
| `restriction` | Language feature restrictions  | `off`   |
| `nursery`     | Experimental rules             | `off`   |

**Recommended approach:** Enable categories broadly, then override specific
rules.

---

## TypeScript Rules

Oxlint supports TypeScript rules natively via `@typescript-eslint` prefix:

```json
{
  "rules": {
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-non-null-assertion": "error",
    "@typescript-eslint/prefer-as-const": "error"
  }
}
```

**Type-Aware Rules:** Some TypeScript rules require type information. Enable
with:

```bash
oxlint --type-aware
```

---

## React Rules

Oxlint includes React and JSX rules:

```json
{
  "rules": {
    "react/jsx-key": "error",
    "react/jsx-no-duplicate-props": "error",
    "react/react-in-jsx-scope": "off",
    "react/prop-types": "off"
  }
}
```

**React Hooks:** Enabled via `react-hooks/rules-of-hooks` and
`react-hooks/exhaustive-deps`.

---

## Import Rules

Oxlint supports import ordering and duplicate detection:

```json
{
  "rules": {
    "import/first": "error",
    "import/no-duplicates": "error",
    "import/order": [
      "error",
      {
        "groups": ["builtin", "external", "internal", "parent", "sibling"],
        "newlines-between": "always"
      }
    ]
  }
}
```

---

## File-Specific Overrides

Use `overrides` to relax rules for specific files:

```json
{
  "overrides": [
    {
      "files": ["**/*.test.ts", "**/*.test.tsx"],
      "rules": {
        "@typescript-eslint/no-explicit-any": "off",
        "no-console": "off"
      }
    },
    {
      "files": ["**/server/**/*.ts"],
      "rules": {
        "no-console": "error"
      }
    }
  ]
}
```

---

## Ignoring Files

Create `.oxlintignore` in root:

```
# Ignore build outputs
dist/
build/
.next/

# Ignore lockfiles
pnpm-lock.yaml

# Ignore generated files
**/*.generated.ts
**/generated/
```

---

## CI/CD Integration

### GitHub Actions

```yaml
- name: Lint
  run: pnpm lint

- name: Format Check
  run: pnpm format:check
```

### Pre-commit Hook (Lefthook)

```yaml
pre-commit:
  commands:
    lint:
      run: pnpm lint:staged
    format:
      run: pnpm format
```

---

## Common Mistakes

### ❌ Wrong: Using ESLint Config Format

```javascript
// WRONG - This is ESLint flat config
export default {
  plugins: ["@typescript-eslint"],
  rules: { ... }
}
```

### ✅ Correct: Use JSON

```json
{
  "rules": {
    "@typescript-eslint/no-explicit-any": "error"
  }
}
```

### ❌ Wrong: JavaScript Plugins for Everything

```json
{
  "plugins": ["turbo", "import", "promise"] // AVOID
}
```

### ✅ Correct: Native Rules First

```json
{
  "rules": {
    "correctness": "error", // Native category
    "import/first": "error" // Only if needed
  }
}
```

---

## Performance Tips

1. **Use categories** instead of individual rules when possible
2. **Avoid JavaScript plugins** — they slow down Oxlint
3. **Run type-aware rules separately** in CI (not in pre-commit)
4. **Use `.oxlintignore`** to skip generated files

---

## Resources

- [Oxlint Documentation](https://oxc.rs/docs/guide/usage/linter)
- [Oxlint Rules](https://oxc.rs/docs/guide/usage/linter/rules)
- [Migration Guide](https://oxc.rs/docs/guide/usage/linter/migrate-from-eslint)
- [Oxfmt Documentation](https://oxc.rs/docs/guide/usage/formatter)
