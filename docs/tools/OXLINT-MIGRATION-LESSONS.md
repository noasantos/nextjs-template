# Oxlint Migration: Lessons Learned

**Date:** 2026-04-04  
**Purpose:** Document critical mistakes made during ESLint → Oxlint migration to
prevent future regressions.

---

## 🔴 Critical Bugs Found (And Fixed)

### Bug #1: Categories Inside `"rules"` Key

**Symptom:** Category enforcement silently disabled — no errors shown for
correctness violations.

**Wrong:**

```json
{
  "rules": {
    "correctness": "error", // ❌ Treated as unknown rule named "correctness"
    "suspicious": "warn", // ❌ Silently ignored
    "perf": "warn" // ❌ Silently ignored
  }
}
```

**Correct:**

```json
{
  "categories": {
    "correctness": "error", // ✅ Proper category key
    "suspicious": "warn",
    "perf": "warn"
  },
  "rules": {
    // ✅ Individual rules only
    "no-console": "error"
  }
}
```

**Why it happened:** ESLint doesn't have a `"categories"` key — everything goes
in `"rules"`. This is an Oxlint-specific feature that's easy to miss.

**How to verify:**

```bash
# After fix, run:
pnpm oxlint -D correctness src/index.ts

# List all active rules — should show correctness rules
pnpm oxlint --rules | grep correctness
```

**Lesson:** Always use `"categories"` for category-level enforcement. Never mix
with `"rules"`.

---

### Bug #2: `@typescript-eslint/` Prefix

**Symptom:** TypeScript rules silently ignored — no errors for `any` types or
non-null assertions.

**Wrong:**

```json
{
  "rules": {
    "@typescript-eslint/no-explicit-any": "error", // ❌ ESLint prefix
    "@typescript-eslint/no-non-null-assertion": "error" // ❌ ESLint prefix
  }
}
```

**Correct:**

```json
{
  "plugins": ["typescript"],
  "rules": {
    "typescript/no-explicit-any": "error", // ✅ Oxlint prefix
    "typescript/no-non-null-assertion": "error" // ✅ Oxlint prefix
  }
}
```

**Why it happened:** Coming from ESLint + `@typescript-eslint/eslint-plugin`,
the prefix is muscle memory. Oxlint uses `typescript/` (no `@eslint` namespace).

**How to verify:**

```bash
# Create test file with explicit any
echo "const x: any = 1;" > /tmp/test.ts

# Should report typescript/no-explicit-any
pnpm oxlint /tmp/test.ts

# Clean up
rm /tmp/test.ts
```

**Lesson:** Oxlint uses `typescript/` prefix, NOT `@typescript-eslint/`.

---

### Bug #3: Oxfmt snake_case Keys

**Symptom:** Oxfmt config silently ignored — formatting doesn't match configured
style.

**Wrong:**

```json
{
  "indent_width": 2, // ❌ snake_case (Prettier uses camelCase)
  "line_width": 100, // ❌ snake_case
  "line_ending": "lf" // ❌ snake_case
}
```

**Correct:**

```json
{
  "tabWidth": 2, // ✅ camelCase (Prettier-compatible)
  "printWidth": 100, // ✅ camelCase
  "endOfLine": "lf" // ✅ camelCase
}
```

**Why it happened:** Snake_case looks more "Rust-like", but Oxfmt intentionally
uses Prettier-compatible camelCase for easy migration.

**How to verify:**

```bash
# Format a file and check it applies settings
echo "const x = { a: 1, b: 2, c: 3 };" > /tmp/test.ts
pnpm oxfmt /tmp/test.ts
cat /tmp/test.ts  # Check line width and indentation
rm /tmp/test.ts
```

**Lesson:** Oxfmt uses Prettier-compatible camelCase, not snake_case.

---

### Bug #4: `$schema` URL Pointing to GitHub

**Symptom:** Schema may lag behind installed version or point to draft schema.

**Wrong:**

```json
{
  "$schema": "https://raw.githubusercontent.com/oxc-project/oxc/main/napi/oxlint/schema.json"
}
```

**Correct:**

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json"
}
```

**Why it happened:** GitHub URL looks more "official", but the local
`node_modules` path is always in sync with installed version.

**How to verify:**

```bash
# Confirm schema file exists after install
ls ./node_modules/oxlint/configuration_schema.json

# Run oxlint and check for schema parse errors
pnpm oxlint --print-config src/index.ts
```

**Lesson:** Use local `node_modules` path for `$schema`, not GitHub URL.

---

### Bug #5: `"import/resolver"` in Settings

**Symptom:** Config loads but resolver settings are ignored (no error, just
silently dropped).

**Wrong:**

```json
{
  "settings": {
    "import/resolver": {
      "typescript": true,
      "node": true
    }
  }
}
```

**Correct:**

```json
{
  "settings": {
    "next": {
      "rootDir": ["apps/*/", "packages/*/"]
    }
  }
}
```

**Why it happened:** This is an ESLint/`eslint-import-resolver-typescript`
pattern. Oxlint's native `import` plugin doesn't use this config.

**Lesson:** Remove `"import/resolver"` — it's an ESLint carryover with no Oxlint
equivalent.

---

### Bug #6: Missing `"plugins"` Key

**Symptom:** Default plugins may be overridden silently, causing some rules to
be unavailable.

**Wrong:**

```json
{
  // No plugins key — relies on defaults
  "rules": {
    "typescript/no-explicit-any": "error"
  }
}
```

**Correct:**

```json
{
  "plugins": ["typescript", "react", "jsx-a11y", "import", "nextjs", "unicorn"],
  "rules": {
    "typescript/no-explicit-any": "error"
  }
}
```

**Why it happened:** ESLint has default plugins. Oxlint requires explicit
declaration when you want to ensure specific plugins are active.

**Important:** Setting `"plugins"` **overwrites defaults**, so be explicit about
everything you need.

**How to verify:**

```bash
# List all active TypeScript rules
pnpm oxlint --rules | grep "typescript/"

# List all active React rules
pnpm oxlint --rules | grep "react/"
```

**Lesson:** Always declare `"plugins"` explicitly to ensure native plugins are
active.

---

## 🟡 Advisory Fixes

### Lefthook: Format Before Lint

**Wrong order:**

```yaml
pre-commit:
  commands:
    lint:
      run: pnpm lint-staged
    format:
      run: pnpm format
```

**Correct order:**

```yaml
pre-commit:
  commands:
    format:
      run: pnpm exec oxfmt --write
      priority: 1
    lint:
      run: pnpm exec oxlint --fix
      priority: 2
```

**Why:** Format code into consistent shape BEFORE linting. Oxlint docs
explicitly recommend "formatter first, then linter".

---

### lint-staged: Use `pnpm exec` Directly

**Wrong:**

```json
{
  "*.{ts,tsx}": [
    "pnpm oxlint" // ❌ Runs against full project, not staged files
  ]
}
```

**Correct:**

```json
{
  "*.{ts,tsx}": [
    "oxlint --fix" // ✅ Receives staged files as arguments
  ]
}
```

**Why:** `pnpm oxlint` ignores staged file arguments. Use `oxlint` directly (or
`pnpm exec oxlint`) to pass staged files.

---

## ✅ Migration Checklist

Run this AFTER migrating to verify everything is correct:

```bash
# 1. Confirm no ESLint config files remain
find . -name ".eslintrc*" -not -path "*/node_modules/*"
find . -name "eslint.config.*" -not -path "*/node_modules/*"
# Expected: no output

# 2. Confirm no @typescript-eslint/ prefixes in config
grep -r "@typescript-eslint" .oxlintrc.json
# Expected: no output

# 3. Confirm categories are NOT in rules
cat .oxlintrc.json | python3 -c "
import json, sys
cfg = json.load(sys.stdin)
rules = cfg.get('rules', {})
cats = ['correctness','suspicious','perf','restriction','nursery','pedantic','style']
found = [c for c in cats if c in rules]
print('ERROR - categories in rules:', found) if found else print('OK')
"

# 4. Confirm Oxfmt config uses camelCase
cat .oxfmtrc.json | python3 -c "
import json, sys
cfg = json.load(sys.stdin)
snake_keys = [k for k in cfg if '_' in k]
print('ERROR - snake_case keys found:', snake_keys) if snake_keys else print('OK')
"

# 5. Verify oxlint version >= 1.0
pnpm oxlint --version

# 6. Test TypeScript rules work
echo "const x: any = 1;" > /tmp/test.ts
pnpm oxlint /tmp/test.ts | grep "typescript/no-explicit-any"
rm /tmp/test.ts
# Expected: should report violation

# 7. Full workflow test
pnpm lint
pnpm format:check
pnpm typecheck
pnpm build
# All should exit 0
```

---

## 📚 Official References

- [Oxlint Configuration](https://oxc.rs/docs/guide/usage/linter/config)
- [Oxfmt Config File Reference](https://oxc.rs/docs/guide/usage/formatter/config-file-reference)
- [Oxlint JS Plugins Alpha](https://oxc.rs/blog/2026-03-11-oxlint-js-plugins-alpha)
- [Oxlint 1.0 Stable Announcement](https://voidzero.dev/posts/announcing-oxlint-1-stable)
- [Oxlint CLI Reference](https://oxc.rs/docs/guide/usage/linter/cli)

---

## 🎯 Key Takeaways

1. **Categories go in `"categories"`, NOT `"rules"`** — This is the #1 migration
   mistake
2. **TypeScript prefix is `typescript/`, NOT `@typescript-eslint/`** — ESLint
   namespace doesn't exist in Oxlint
3. **Oxfmt uses Prettier-compatible camelCase** — Not snake_case
4. **Use local `$schema` path** — Not GitHub raw URL
5. **Remove ESLint carryovers** — `import/resolver`, `@typescript-eslint/`, etc.
6. **Declare plugins explicitly** — Don't rely on defaults
7. **Format BEFORE lint** — Formatter first, then linter

---

**Last Updated:** 2026-04-04  
**Version:** 1.0.0  
**Status:** All bugs fixed and verified
