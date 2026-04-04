# Git Hooks & Automation

## TL;DR

- **`git commit`** runs **Lefthook `pre-commit`**: format + lint + policy checks
  on the **whole repo** (not only staged files). If a step **fails**, the commit
  is **aborted**; some steps **rewrite files** and, when successful,
  **`stage_fixed`** re-stages those fixes into your commit.
- **`git push`** runs **Lefthook `pre-push`**: slower checks (typecheck, tests,
  audit, etc.). Failures **block the push**.
- **Editor extensions** (format on save, Ox in the IDE, etc.) help your
  **local** workflow; they are **not** a substitute for hooks. The
  **authoritative** alignment with this repo is what runs when Git invokes
  Lefthook.

## IDE / extensions vs Git hooks

|            | Editor (save, format document, etc.)  | `git commit` / `git push`                    |
| ---------- | ------------------------------------- | -------------------------------------------- |
| **When**   | On each save or manual command        | Only when you commit or push                 |
| **Config** | May differ (user settings, workspace) | **`lefthook.yml`** + root **`pnpm`** scripts |
| **Scope**  | Often current file                    | Pre-commit: **entire tree** (Ox is fast)     |

So: you can have extensions that format with Oxfmt/Ox on save, but **you still
need a successful hook run** before a commit lands. If the hook fails, fix or
stage what it changed and commit again—do not assume “save fixed everything.”

## Pre-commit (`lefthook` → `pre-commit`)

**Trigger:** every `git commit` (after you resolve merge conflicts in the index,
if any).

**Manual run (same as Git):**

```bash
pnpm exec lefthook run pre-commit
```

**Order** (`parallel: false`): each step waits for the previous one.

1. **`pnpm format`** — `oxfmt .` at repo root (respects `.oxfmtrc.json`
   ignores).
2. **`pnpm exec oxlint --fix`** — single pass, root `.oxlintrc.json` (e.g.
   `packages/ui/**` ignored for Oxlint per GR-001).
3. **Changelog** — `scripts/ci/check-changelog.mjs` (must pass for template
   policy).
4. **Security** — `check-security-smells`
5. **Forbidden / patterns** — `check:forbidden`, `check-forbidden-patterns`
6. **Type escapes** — `check-type-escapes`
7. **Workspace imports** — `check:workspace-imports`
8. **Cursor rules parity** — `check:cursor-rules-parity`
9. **Docs drift** — `check:docs-drift`

**Auto-fix vs block:**

- **Oxfmt** and **`oxlint --fix`** may **change files** (style and many safe
  lint fixes). With `stage_fixed: true`, Lefthook **re-adds** those files to the
  index when the step **succeeds**.
- **Anything that exits non-zero** (changelog missing, forbidden pattern,
  security script, **Oxlint error**, etc.) **stops** the hook and **cancels**
  the commit. There is no universal “fix all errors automatically”—only what
  each tool’s fixer covers.
- **Warnings** from Oxlint do not necessarily fail the run; **errors** do.

**Partial staging:** If the **same file** is both staged and unstaged (`MM`),
auto-fix + re-stage can interact badly with unstaged hunks (see
[lefthook#1369](https://github.com/evilmartians/lefthook/issues/1369)). Prefer
staging **all** hunks you intend to commit for that file (`git add -A` on that
set) before committing.

## Commit-msg

Validates [Conventional Commits](https://www.conventionalcommits.org/) via
Commitlint (`commitlint.config.js`).

**Example:**

```bash
git commit -m "feat: add new feature"   # OK
git commit -m "added stuff"              # rejected
```

**Format:** `type(scope?): subject` — types include `feat`, `fix`, `docs`,
`style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

## Pre-push (`lefthook` → `pre-push`)

**Trigger:** `git push` (to any remote ref that runs the hook).

**Manual run:**

```bash
pnpm exec lefthook run pre-push
```

**Checks** (see `lefthook.yml` for the exact list):

- Typecheck — `pnpm typecheck`
- Unit tests — `pnpm test`
- Package exports — `publint` on `packages/*`
- Dead code — `knip` (non-blocking exit code where configured)
- Audit — `pnpm audit --audit-level=high`
- Boundaries — `depcruise` on `apps/*/app` and `packages/*/src`

Failures **block the push**. Fix locally, commit, push again.

## Other automation

**Lint-staged** (`.lintstagedrc`) is available for **`pnpm lint:staged`** (e.g.
CI or ad-hoc staged-only lint). **Pre-commit does not use lint-staged**; it uses
full-repo format + Oxlint as above.

**Post-merge** runs `pnpm install` after `git pull` merge (see `lefthook.yml`).

## Branch naming

Validated by Git-branch-lint (`.branchlintrc.json`):

- `feature/:name`, `bugfix/:ticket-:name`, `hotfix/:ticket-:name`, `docs/:name`,
  `chore/:name`, `test/:name`, `refactor/:name`

**Excluded:** `main`, `master`, `develop`, `staging`, `production`

## Commands

```bash
# Install Git hooks (after clone or when lefthook.yml changes)
pnpm hooks:install

pnpm hooks:uninstall

# Same checks Git runs before commit
pnpm exec lefthook run pre-commit

# Same checks Git runs before push
pnpm exec lefthook run pre-push

# Staged-only lint (optional; not the pre-commit pipeline)
pnpm lint:staged

# Validate last commit message
echo "feat: example" | npx commitlint
```

## Configuration files

| File                   | Role                            |
| ---------------------- | ------------------------------- |
| `lefthook.yml`         | Hook commands and order         |
| `commitlint.config.js` | Commit message rules            |
| `.lintstagedrc`        | Patterns for `pnpm lint:staged` |
| `.branchlintrc.json`   | Branch name rules               |

---

**For AI agents:** Hooks run automatically with Git. Do **not** use
`git commit --no-verify` or `git push --no-verify` unless a maintainer
explicitly allows an exception; document why if you must.
