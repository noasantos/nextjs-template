# Command Reference

Quick reference for all common commands.

## Root Commands

```bash
# Install all dependencies
pnpm install

# Start all apps in development
pnpm dev

# Build deployable apps only
pnpm build

# Lint all apps and packages
pnpm lint

# Format all files (with Prettier)
pnpm format

# Check formatting without changes (CI)
pnpm format:check

# Targeted docs-vs-code drift checks
pnpm check:docs-drift

# Repo security guards (also run in CI)
pnpm check:security-smells

# Dependency audit (CI runs this as informational until lockfile is clean)
pnpm audit:dependencies

# Type check all apps and packages
pnpm typecheck

# Full pipeline before commit: lint → typecheck → build → format
pnpm workflow

# After `pnpm workflow` succeeds: review diff, then `git add -A` (unless a partial commit
# was explicitly requested) and commit with an English Conventional Commit message.
# See AGENTS.md → "Commit workflow (mandatory)".

# Run unit tests
pnpm test

# Watch unit tests
pnpm test:watch

# Prepare local Supabase for DB suites
pnpm test:integration:prepare

# Run Supabase-backed integration tests (workspace package @workspace/tests)
pnpm test:integration

# Run RLS suites (@workspace/tests)
pnpm test:rls

# Run pgTAP / SQL tests
pnpm test:sql
```

Unit tests live under [`tests/unit/`](../../tests/README.md): workspace packages and each app (`tests/unit/<app>/` mirrors `apps/<app>/`). Integration and RLS use `tests/integration/` and `tests/rls/`. Run `pnpm test` from the repo root so `.env.test` loads. There is no root e2e suite in this tree.

Repo automation (`check:forbidden`, Supabase migration wrappers, etc.): [`scripts/README.md`](../../scripts/README.md).

### Supabase migrations (local)

Create new migration files **only** via the stamped script; capture SQL with `db diff` into the same path. See [docs/guides/migration-workflow.md](../guides/migration-workflow.md).

```bash
# 1) Create stamped migration file (required first step). Prints one line: path to the new .sql file.
pnpm supabase:migration:new -- descriptive_migration_name

# 2) After local DDL, write diff into that file (use the path from step 1)
pnpm supabase db diff -o supabase/migrations/<timestamp>_descriptive_migration_name.sql

# 3) If the diff overwrote the header comments
pnpm supabase:migration:stamp -- supabase/migrations/<timestamp>_descriptive_migration_name.sql
```

---

## App-Specific Commands

### Example app (`apps/example`)

Serves `/` and auth routes (`/sign-in`, `/callback`, …) (default dev port **3000**).

```bash
# Start development server
pnpm --filter example dev

# Open the canonical sign-in route
open http://localhost:3000/sign-in

# Build for production
pnpm --filter example build

# Lint
pnpm --filter example lint

# Type check
pnpm --filter example typecheck

# Test
pnpm --filter example test

# Build and summarize client bundle output
pnpm bundle:analyze:example
```

---

## Package Commands

### @workspace/ui

```bash
# Lint
pnpm --filter @workspace/ui lint

# Type check
pnpm --filter @workspace/ui typecheck

# Add shadcn component
pnpm dlx shadcn@latest add button --cwd packages/ui
```

### @workspace/brand

```bash
# Lint
pnpm --filter @workspace/brand lint

# Type check
pnpm --filter @workspace/brand typecheck
```

Shared product UI components live here — **not** in `packages/ui` (see [AGENTS.md](../../AGENTS.md)).

### @workspace/supabase-auth

```bash
# Lint
pnpm --filter @workspace/supabase-auth lint

# Type check
pnpm --filter @workspace/supabase-auth typecheck

# Test
pnpm --filter @workspace/supabase-auth test
```

### @workspace/supabase-infra

```bash
# Lint
pnpm --filter @workspace/supabase-infra lint

# Type check
pnpm --filter @workspace/supabase-infra typecheck

# Unit tests
pnpm --filter @workspace/supabase-infra test

# Integration tests
pnpm --filter @workspace/supabase-infra test:integration

# RLS tests
pnpm --filter @workspace/supabase-infra test:rls
```

### @workspace/supabase-data

```bash
# Lint
pnpm --filter @workspace/supabase-data lint

# Type check
pnpm --filter @workspace/supabase-data typecheck

# Unit tests
pnpm --filter @workspace/supabase-data test

# Integration tests
pnpm --filter @workspace/supabase-data test:integration
```

### @workspace/forms

```bash
# Lint
pnpm --filter @workspace/forms lint

# Type check
pnpm --filter @workspace/forms typecheck

# Test
pnpm --filter @workspace/forms test
```

### @workspace/eslint-config

```bash
# Lint (self-check)
pnpm --filter @workspace/eslint-config lint
```

### @workspace/typescript-config

No commands - JSON config files only.

### @workspace/vitest-config

```bash
# Type check
pnpm --filter @workspace/vitest-config typecheck
```

---

## Turborepo Commands

```bash
# Run task in all packages
pnpm turbo run build

# Run task with cache
pnpm turbo run build --cache-dir=.turbo

# Run task without cache
pnpm turbo run build --no-cache

# Run task in specific package
pnpm turbo run build --filter=example

# Run task with dependencies
pnpm turbo run build --filter=example...

# Dry run (see what would run)
pnpm turbo run build --dry

# Generate graph of tasks
pnpm turbo run build --graph=out.svg
```

---

## pnpm Workspace Commands

```bash
# List all workspace packages
pnpm list -r --depth=0

# Install specific package
pnpm add react --filter example

# Update dependency across all packages
pnpm update react --recursive

# Remove dependency
pnpm remove lodash --recursive

# Run command in all packages
pnpm -r exec echo "Hello from $PWD"
```

---

## Git Commands

```bash
# Check status
git status

# View recent commits
git log --oneline -10

# Stage all changes
git add .

# Commit with message
git commit -m "feat: add new feature"

# Push to remote
git push origin main

# Pull from remote
git pull origin main
```

---

## Useful Aliases

Add these to your shell config (`~/.zshrc` or `~/.bashrc`):

```bash
# Quick dev
alias dev="pnpm dev"
alias build="pnpm build"
alias lint="pnpm lint"
alias test="pnpm test"

# App-specific
alias dev-example="pnpm --filter example dev"

# Type check all
alias tc="pnpm typecheck"
```

---

## Environment Setup

```bash
# Check Node version (should be 20+)
node --version

# Check pnpm version (should be 10.33.0)
pnpm --version

# Install pnpm if needed
npm install -g pnpm@10.33.0

# Enable pnpm shell completion (add to ~/.zshrc)
source <(pnpm completion)
```

---

## Prettier Configuration

### Format Files

```bash
# Format all files in the project
pnpm format

# Format specific app
pnpm --filter example format

# Check formatting without changes (for CI)
pnpm format:check
```

### What Gets Formatted

- ✅ TypeScript/TSX files (`.ts`, `.tsx`)
- ✅ JavaScript files (`.js`, `.jsx`)
- ✅ JSON files
- ✅ Markdown files
- ✅ CSS/SCSS files

### Formatting Rules

- **Semi-colons:** Always required
- **Quotes:** Single quotes
- **Tab width:** 2 spaces
- **Trailing commas:** ES5 (objects, arrays, etc.)
- **Print width:** 100 characters
- **Import order:** React → Third-party → @workspace/\* → Relative
- **Tailwind classes:** Automatically sorted

### VSCode Auto-Format

Files are formatted on save when using VSCode. Ensure you have the Prettier extension installed.

---

## See Also

- [Root README](../README.md)
- [Architecture Overview](../architecture/overview.md)
