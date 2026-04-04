# Git Hooks & Automation

## Tools

**Lefthook** - Git hooks manager (fast, parallel, zero dependencies)  
**Lint-staged** - Run linters on staged files only  
**Commitlint** - Validate conventional commits  
**Git-branch-lint** - Validate branch naming

## Installation

```bash
pnpm hooks:install
```

## Pre-commit Hooks

**Runs automatically before each commit:**

```bash
pnpm exec lefthook run pre-commit
```

**Checks:**

- ✅ Format + lint **staged files only** (`oxfmt` / `oxlint` use Lefthook
  `{staged_files}` — not a full-repo `pnpm lint`)
- ✅ Security scan (check-security-smells)
- ✅ Forbidden patterns (check-forbidden)
- ✅ Docs drift (check-docs-drift)

**Partial staging (important):** If the same file is **staged and also edited
unstaged** (git shows `MM`), Lefthook backs up unstaged lines, runs the
formatter, then tries to re-apply that backup. If the formatter rewrites nearby
lines, `git apply` can fail and the working tree can end up wrong (see
[evilmartians/lefthook#1369](https://github.com/evilmartians/lefthook/issues/1369)).
**Prefer `git add` / `git add -A` on everything you intend to commit** before
`git commit`, so you are not mixing staged + unstaged edits on the same file.

**Execution order:** Pre-commit uses `parallel: false` so `priority` is honored:
`oxfmt` → `oxlint` → changelog and other checks (not parallel format+lint).

## Commit-msg Hooks

**Validates commit message format:**

```bash
git commit -m "feat: add new feature"  # ✅ Valid
git commit -m "added stuff"            # ❌ Invalid
```

**Format:** `type(scope?): subject`

**Types:** feat, fix, docs, style, refactor, perf, test, build, ci, chore,
revert

## Pre-push Hooks

**Runs before push:**

```bash
git push  # Automatically runs pre-push checks
```

**Checks:**

- ✅ Type check (pnpm typecheck)
- ✅ Unit tests (pnpm test)
- ✅ Dependency audit (pnpm audit)

## Branch Naming

**Validated patterns:**

- `feature/:name`
- `bugfix/:ticket-:name`
- `hotfix/:ticket-:name`
- `docs/:name`
- `chore/:name`
- `test/:name`
- `refactor/:name`

**Excluded branches:** main, master, develop, staging, production

## Commands

```bash
# Install hooks
pnpm hooks:install

# Uninstall hooks
pnpm hooks:uninstall

# Run pre-commit manually
pnpm lint

# Run lint-staged manually
pnpm lint:staged

# Run commitlint manually
npx commitlint --edit
```

## Configuration Files

- `lefthook.yml` - Git hooks configuration
- `commitlint.config.js` - Commit message rules
- `.lintstagedrc` - Lint-staged file patterns
- `.branchlintrc.json` - Branch naming patterns

---

**For AI Agents:** All hooks run automatically. NEVER bypass with `--no-verify`
unless absolutely necessary.
