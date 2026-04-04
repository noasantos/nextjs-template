> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/supabase-migrations.mdc`](../../../.cursor/rules/supabase-migrations.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# Supabase migrations (mandatory)

## Creating a new migration file

1. **ONLY** create new files under `supabase/migrations/` by running from the
   repository root:

   `pnpm supabase:migration:new -- <descriptive_name>`

   This runs `supabase migration new` and stamps the file with
   `migration-created-via` and `created-at-utc` metadata (see
   `scripts/supabase/migration-new.sh`). **Stdout:** one repo-relative path line
   for `db diff -o` (Supabase CLI success text is suppressed).

2. **Do not** create migration files with `touch`, `echo`, editor “new file”, or
   copy-paste into a path you invented. **Do not** use
   `pnpm supabase db diff -f <name>` (or `supabase db diff --file …`) as the
   **sole** step to create a migration file — that bypasses the stamped
   workflow.

3. **Capture schema changes** after applying DDL on the local database (Studio,
   psql, etc.):
   - Write the diff into the **same** file the step above created, e.g.  
     `pnpm supabase db diff -o supabase/migrations/<timestamp>_<descriptive_name>.sql`  
     (use the exact single-line path from `supabase:migration:new`).
   - If the diff step **replaces** the file and removes the header comments,
     restore them with:  
     `pnpm supabase:migration:stamp -- supabase/migrations/<that-file>.sql`

4. **Never** hand-edit migration SQL except when reconciling a bad diff (prefer
   fixing DDL locally and re-diffing). Never commit migrations that skip the
   header stamp without an explicit maintainer exception.

Canonical docs: `docs/architecture/database.md` → Migrations,
`docs/guides/migration-workflow.md`.
