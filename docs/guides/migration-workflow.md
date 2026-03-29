# Migration Workflow Guide

## Critical rule

**New files under `supabase/migrations/` MUST be created with `pnpm supabase:migration:new -- <descriptive_name>`.**  
Do not use `touch`, shell redirects, or `pnpm supabase db diff -f <name>` **alone** as the only step — that creates an unstamped migration file and bypasses the required header.

**Violations can break review, automation, and production deployments.**

---

## The allowed workflow

### Step 1: Make changes locally

Use one of these to modify your **local** database:

- Supabase Studio (http://localhost:54323)
- pgAdmin
- `psql`
- Any SQL client

```sql
-- Example: Create a table in local DB
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

### Step 2: Create the migration file (required entry point)

From the repository root:

```bash
pnpm supabase:migration:new -- create_users_table
```

This runs `supabase migration new`, then stamps the file with:

- `-- migration-created-via: pnpm supabase:migration:new`
- `-- created-at-utc: <ISO timestamp>`

**Output:** one line — the repo-relative path to the new file (e.g. `supabase/migrations/YYYYMMDDHHMMSS_create_users_table.sql`). Use that exact path in the next step. (`pnpm` may print a short task line before it.)

### Step 3: Capture the schema diff into that file

```bash
pnpm supabase db diff -o supabase/migrations/YYYYMMDDHHMMSS_create_users_table.sql
```

Use the **exact** path from step 2.

If `db diff` **overwrites** the file and removes the stamp lines, restore them:

```bash
pnpm supabase:migration:stamp -- supabase/migrations/YYYYMMDDHHMMSS_create_users_table.sql
```

### Step 4: Review and commit

```bash
git add supabase/migrations/YYYYMMDDHHMMSS_create_users_table.sql
git commit -m "feat: add users table with RLS"
```

---

## Forbidden

```bash
# ❌ Creating a migration path without migration:new
echo "CREATE TABLE ..." > supabase/migrations/20260324000000_manual.sql

# ❌ Using only db diff --file / -f to create the migration (unstamped)
pnpm supabase db diff -f create_users_table

# ❌ Renaming migration files
mv supabase/migrations/20260324000000_old.sql supabase/migrations/20260324000001_new.sql
```

### Remote / hosted database — agents

**Do not** run against a **linked remote** Supabase project from agent/automation for schema writes. Use **local** `supabase start`, `pnpm supabase db reset`, and the workflow above; ship SQL via **committed migrations** and your CI/CD. See [AGENTS.md](../AGENTS.md) and [docs/guides/supabase-setup.md](./supabase-setup.md).

---

## Allowed: SQL for local exploration

You CAN run SQL locally for experiments; capture changes into a migration with **step 2–3** above, not by inventing a new file path.

```sql
-- ✅ OK: Experiment in local DB, then migration:new + db diff -o
ALTER TABLE users ADD COLUMN phone text;
```

Seeds belong in seed files (e.g. `supabase/seed.sql`), not ad-hoc migration paths.

---

## Common scenarios

### Adding a table

1. Create the table in the local DB (Studio).
2. `pnpm supabase:migration:new -- create_posts_table`
3. `pnpm supabase db diff -o supabase/migrations/<timestamp>_create_posts_table.sql`
4. `pnpm supabase:migration:stamp` if the header was lost.

### Fixing a mistake before commit

If the migration file is **not** pushed yet: reset local DB if needed, remove the bad file, and repeat steps 2–3. **Do not** edit committed migrations in place — add a new migration.

---

## Checklist before committing

- [ ] File was created with `pnpm supabase:migration:new -- <name>`
- [ ] SQL came from `pnpm supabase db diff -o <that path>` (or equivalent CLI capture)
- [ ] Header comments are present (or restored with `pnpm supabase:migration:stamp`)
- [ ] Migration name is descriptive (not `fix` / `update` alone)
- [ ] RLS enabled on new tables; policies and indexes per [DATABASE.md](../architecture/database.md)
- [ ] Test delta per [DATABASE.md — Migration test delta](../architecture/database.md#migration-test-delta-required)

---

## Related documentation

- **[Database → Migrations](../architecture/database.md#migrations)** — Canonical rules (`docs/architecture/database.md`)
- **[Golden Rules GR-015](../standards/golden-rules.md#gr-015-cli-generated-migrations-only-critical---human-confirmation-required)**
- **[Anti-Patterns BAD-015](../standards/anti-patterns.md#bad-015-manual-migration-files-critical---prohibited)**
- **[AGENTS.md](../AGENTS.md)** — Agent restrictions

---

## Quick reference

```bash
pnpm supabase:migration:new -- <descriptive_name>
pnpm supabase db diff -o supabase/migrations/<timestamp>_<descriptive_name>.sql
pnpm supabase:migration:stamp -- supabase/migrations/<timestamp>_<descriptive_name>.sql   # if needed

pnpm supabase db reset   # local only, when you need a clean apply
```

**Last updated:** 2026-03-28
