# Database Standards

## Core Principles

This document establishes the gold-standard for database development. All new
code MUST follow these patterns.

### Golden Rules

- **ALWAYS** enable RLS on all tables (RLS-first design)
- **NEVER** create migration files manually (always via
  `pnpm supabase:migration:new` + CLI capture; see [Migrations](#migrations))
- **ALWAYS** use environment guardrails (local/staging/production)
- **NEVER** run production migrations locally (pipeline-only)
- **ALWAYS** use `search_path = ''` in database functions
- **ALWAYS** validate external data with Zod at boundaries

### Agent and remote safety

- **Development and schema work** target the **local** Supabase instance
  (`supabase start`). Use `.env.local` values from `pnpm exec supabase status` —
  see [docs/guides/supabase-setup.md](../guides/supabase-setup.md).
- **AI agents** must not run CLI commands or MCP tools that **write** to
  **remote** hosted databases (migration apply, `db push`, arbitrary DDL/DML)
  unless a human explicitly approves an out-of-band process. Promote schema
  changes via **migrations in git** and your deployment pipeline, not ad-hoc
  remote edits from automation.
- See
  [AGENTS.md § Remote database and MCP](../../AGENTS.md#remote-database-and-mcp-agents).

---

## RLS-First Design

### Rule: All Tables MUST Have RLS Enabled

Row Level Security (RLS) is the primary authorization mechanism. **EVERY** table
MUST have RLS enabled from creation.

```sql
-- ✅ CORRECT — RLS enabled from start
CREATE TABLE entities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE entities ENABLE ROW LEVEL SECURITY;

-- ❌ FORBIDDEN — Table without RLS
CREATE TABLE entities (
  id uuid PRIMARY KEY
);
-- Missing: ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
```

### RLS Policy Design

Policies MUST be:

- **Granular**: Separate policies per operation (SELECT, INSERT, UPDATE, DELETE)
- **Role-specific**: Separate policies per role (authenticated, anon, specific
  roles)
- **Explicit**: Clear ownership or permission checks

```sql
-- ✅ CORRECT — Granular, role-specific policies
CREATE POLICY "Users can view own entities"
  ON entities FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own entities"
  ON entities FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own entities"
  ON entities FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own entities"
  ON entities FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ❌ WRONG — Single policy for all operations
CREATE POLICY "All operations"
  ON entities FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);  -- Too permissive!
```

### Helper Functions for RLS

Create helper functions for complex authorization logic:

```sql
-- ✅ CORRECT — Helper function for authorization
CREATE OR REPLACE FUNCTION entity_owner_check(entity_id uuid)
RETURNS boolean AS $$
  EXISTS (
    SELECT 1 FROM entities
    WHERE id = entity_id AND user_id = auth.uid()
  )
$$ LANGUAGE SQL SECURITY INVOKER STABLE;

-- Use in policy
CREATE POLICY "Owners can manage entities"
  ON entities FOR ALL
  TO authenticated
  USING (entity_owner_check(id))
  WITH CHECK (entity_owner_check(id));
```

### Performance Considerations

- **ALWAYS** add indexes on columns used in RLS policies
- **NEVER** use subqueries in RLS when joins are possible
- **ALWAYS** test policy performance with realistic data volumes
- **ALWAYS** review `EXPLAIN` / `EXPLAIN ANALYZE` before calling a policy or
  query change a performance fix

```sql
-- ✅ CORRECT — Index for RLS policy
CREATE INDEX idx_entities_user_id ON entities(user_id);

-- Policy can now efficiently filter by user_id
CREATE POLICY "Users see own entities"
  ON entities FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
```

### Service role boundary (application layer)

- **RLS** remains the default authorization barrier for data accessed with the
  **publishable** Supabase client.
- **`createAdminClient()`**
  ([`packages/supabase-infra/src/clients/create-admin-client.ts`](../../packages/supabase-infra/src/clients/create-admin-client.ts))
  uses **`SUPABASE_SERVICE_ROLE_KEY`** and **bypasses RLS**. It is
  **server-only** and must **never** appear in client bundles or under
  `NEXT_PUBLIC_*`.
- **Allowlisted usage:** implementation and tests under
  `packages/supabase-infra/src/clients/create-admin-client.ts` (+ its unit test)
  and server actions / internal modules in **`@workspace/supabase-data`**.
  **`pnpm check:forbidden`** rejects `createAdminClient` references in
  **`apps/**`\*\* and other packages.
- When migrations, policies, RPCs, or authz-sensitive queries change, run
  **`pnpm test:db`** (pgTAP), **`pnpm test:rls`**, **`pnpm test:sql`** (Vitest
  integration + RLS), or **`pnpm test:db:all`** (all three in sequence) before
  merge as appropriate — unit coverage does not prove RLS
  ([Testing](./testing.md)).

---

## Migrations

### Supabase CLI (single migration track)

Application schema (RLS, tables, RPCs) lives only in
[`supabase/migrations/`](../../supabase/migrations/). **New migration files**
MUST be created with the repo script
`pnpm supabase:migration:new -- <descriptive_name>` (which wraps
`supabase migration new` and stamps metadata). **Do not** create files under
`supabase/migrations/` with `touch`, redirects, or an editor without that
command. See
[Rule: Never create migration files manually](#rule-never-create-migration-files-manually)
and
[Golden Rules GR-015](../standards/golden-rules.md#gr-015-cli-generated-migrations-only-critical---human-confirmation-required).

**Related:** [`.env.example`](../../.env.example),
[AGENTS.md — Critical rules](../../AGENTS.md#critical-rules-non-negotiable),
[docs/guides/migration-workflow.md](../guides/migration-workflow.md).

### Rule: Never create migration files manually

**ALL** new rows in `supabase/migrations/*.sql` MUST start from
`pnpm supabase:migration:new -- <name>`. **SQL content** MUST come from the
Supabase CLI (typically `pnpm supabase db diff -o <path-to-that-file>` after
local DDL), not from ad-hoc copy-paste into a hand-made path.

### Workflow

```bash
# 1) Create the migration file (ONLY supported way to create the file on disk)
pnpm supabase:migration:new -- add_entities_table
# Prints one line: repo-relative path, e.g. supabase/migrations/YYYYMMDDHHMMSS_add_entities_table.sql

# 2) Apply DDL on the local database (Studio, psql, …), then capture the diff into THAT file
pnpm supabase db diff -o supabase/migrations/YYYYMMDDHHMMSS_add_entities_table.sql

# If step 2 overwrote the file and removed the header comments, restore them:
pnpm supabase:migration:stamp -- supabase/migrations/YYYYMMDDHHMMSS_add_entities_table.sql

# ❌ FORBIDDEN — Creating a migration path without migration:new
# touch supabase/migrations/YYYYMMDDHHMMSS_manual_change.sql
# pnpm supabase db diff -f add_entities_table   # alone: creates an unstamped migration file — do not use as the sole create step
```

### Migration Naming

- **ALWAYS** use descriptive, imperative names in
  `pnpm supabase:migration:new -- <name>`
- **NEVER** use generic names like "update_schema" or "fix_table"

```bash
# ✅ CORRECT — Descriptive names (argument to migration:new)
pnpm supabase:migration:new -- create_users_table
pnpm supabase:migration:new -- add_email_to_entities
pnpm supabase:migration:new -- create_entity_ownership_policies

# ❌ WRONG — Generic names
pnpm supabase:migration:new -- update_schema
pnpm supabase:migration:new -- fix_stuff
pnpm supabase:migration:new -- changes
```

### Migration test delta (required)

**Rule:** Any new or materially changed file under `supabase/migrations/*.sql`
must land with a **test delta** in the same change set—unless maintainers
explicitly approve a documented exception (e.g. emergency hotfix with a
follow-up ticket).

| Change touches                                                                | Extend                                                                                               |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Schema invariants, policies, RPCs, or SQL behavior you can assert in-database | [`supabase/tests/pgtap/`](../../supabase/tests/pgtap/) (add or update `.sql` tests)                  |
| Client-visible RLS, session roles, or infra code paths                        | RLS-focused tests following patterns in [`packages/supabase-infra/`](../../packages/supabase-infra/) |

**Verify locally:** [`pnpm test:db`](./testing.md) runs pgTAP via
`supabase test db`; [`pnpm test:rls`](./testing.md) runs the Vitest RLS suites;
[`pnpm test:sql`](./testing.md) runs Vitest integration + RLS together;
[`pnpm test:db:all`](./testing.md) runs integration, RLS, then pgTAP. Details
and prerequisites: [Testing](./testing.md).

### Migration Review Checklist

Before committing migrations:

- [ ] **Test delta** satisfied per
      [Migration test delta (required)](#migration-test-delta-required) (pgTAP
      and/or RLS tests as applicable)
- [ ] Migration file was created with `pnpm supabase:migration:new` and SQL
      captured via CLI (`db diff`), not a hand-made path
- [ ] RLS is enabled on all new tables
- [ ] Policies are granular (per operation + role)
- [ ] Indexes exist for policy-filtered columns
- [ ] No `select("*`) in database functions
- [ ] All functions have `search_path = ''`

**TDD order with schema changes:** [TDD](./tdd.md) (contracts and tests
coordinate with local DDL + `pnpm supabase:migration:new` +
`pnpm supabase db diff -o …`; do not invent migration paths by hand).

---

## Environment Guardrails

### Environment Separation

| Environment | Project Ref    | Access          | Migration Method    |
| ----------- | -------------- | --------------- | ------------------- |
| Local       | `local`        | Developers only | `supabase db push`  |
| Staging     | `staging-*`    | Team            | CI/CD pipeline      |
| Production  | `production-*` | Restricted      | CI/CD pipeline only |

### Local Development

```bash
# ✅ CORRECT — Local development workflow
supabase start                    # Start local Supabase
pnpm supabase:migration:new -- feature_name   # Create stamped migration file
# apply DDL locally, then:
pnpm supabase db diff -o supabase/migrations/<timestamp>_feature_name.sql

# ❌ FORBIDDEN — Production operations locally
supabase link --project-ref prod-xyz  # Never link production!
supabase db pull --linked             # Never pull from production!
```

### Production is Pipeline-Only

**NEVER** run migrations directly on production. Production changes MUST go
through CI/CD.

```bash
# ✅ CORRECT — Production via pipeline
git push origin main  # Triggers CI/CD
# CI/CD runs: supabase db push --db-url $PROD_CONNECTION_STRING

# ❌ FORBIDDEN — Direct production operations
supabase link --project-ref prod-xyz
supabase db push  # NEVER run directly on production!
```

### Environment Variables

```env
# ✅ CORRECT — Separate env vars per environment
SUPABASE_URL_LOCAL=http://localhost:54321
SUPABASE_URL_STAGING=https://staging-project.supabase.co
SUPABASE_URL_PRODUCTION=https://prod-project.supabase.co

SUPABASE_ANON_KEY_STAGING=eyJ...
SUPABASE_ANON_KEY_PRODUCTION=eyJ...

# ❌ WRONG — Single env var for all environments
SUPABASE_URL=https://...  # Which environment?
```

---

## SQL Style Guide

### Naming Conventions

| Object    | Convention             | Example                                |
| --------- | ---------------------- | -------------------------------------- |
| Tables    | snake_case, plural     | `users`, `entities`, `audit_logs`      |
| Columns   | snake_case, singular   | `id`, `created_at`, `user_id`          |
| Functions | snake_case, verb-first | `get_entity_by_id`, `check_permission` |
| Policies  | Descriptive sentence   | `"Users can view own entities"`        |
| Indexes   | `idx_{table}_{column}` | `idx_entities_user_id`                 |
| Triggers  | `trg_{table}_{event}`  | `trg_entities_updated_at`              |

### Formatting Standards

```sql
-- ✅ CORRECT — Consistent formatting
CREATE TABLE entities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  user_id uuid NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_entities_user_id ON entities(user_id);

COMMENT ON TABLE entities IS 'User-created entities';
COMMENT ON COLUMN entities.user_id IS 'Owner reference';

-- ❌ WRONG — Inconsistent formatting
CREATE TABLE entities(id uuid primary key,name text not null);
```

### Comments

**ALWAYS** add comments for:

- Table purpose
- Non-obvious column meanings
- Complex business logic in functions

```sql
-- ✅ CORRECT — Descriptive comments
COMMENT ON TABLE entities IS 'Core business entities owned by users';
COMMENT ON COLUMN entities.status IS 'Draft | Published | Archived';
COMMENT ON FUNCTION entity_owner_check IS 'Returns true if current user owns entity';

-- ❌ WRONG — No documentation
-- Future developers cannot understand schema intent
```

---

## Database Functions

### Security Rules

**ALL** database functions MUST:

1. Use `SECURITY INVOKER` (unless `SECURITY DEFINER` is explicitly required)
2. Set `search_path = ''` to prevent schema hijacking
3. Use fully qualified names for all objects

```sql
-- ✅ CORRECT — Secure function
CREATE OR REPLACE FUNCTION get_entity_by_id(target_id uuid)
RETURNS TABLE (
  id uuid,
  name text,
  user_id uuid
) AS $$
BEGIN
  RETURN QUERY
  SELECT e.id, e.name, e.user_id
  FROM entities e
  WHERE e.id = target_id;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = '';

-- ❌ FORBIDDEN — Insecure function
CREATE OR REPLACE FUNCTION get_entity(target_id uuid)
RETURNS entities AS $$
  SELECT * FROM entities WHERE id = target_id;  -- No search_path!
$$ LANGUAGE sql;  -- Uses SECURITY DEFINER by default!
```

### Function Naming

**ALWAYS** use verb-first naming:

```sql
-- ✅ CORRECT — Verb-first naming
CREATE FUNCTION get_entity_by_id(...)
CREATE FUNCTION create_entity(...)
CREATE FUNCTION update_entity_status(...)
CREATE FUNCTION check_entity_permission(...)
CREATE FUNCTION delete_entity(...)

-- ❌ WRONG — Noun-first or unclear naming
CREATE FUNCTION entity_get(...)
CREATE FUNCTION new_entity(...)
CREATE FUNCTION entity_updater(...)
```

### Return Types

**PREFER** returning `TABLE` or specific types over `SETOF entities`:

```sql
-- ✅ CORRECT — Explicit return type
CREATE FUNCTION get_entity_summary(entity_id uuid)
RETURNS TABLE (
  id uuid,
  name text,
  owner_email text,
  created_at timestamptz
) AS $$ ... $$ LANGUAGE plpgsql;

-- ❌ WRONG — Returning entire row type
CREATE FUNCTION get_entity(entity_id uuid)
RETURNS SETOF entities AS $$ ... $$ LANGUAGE plpgsql;
```

---

## RLS Policies

### Policy Structure

**ALWAYS** follow this structure:

```sql
-- Template
CREATE POLICY "[Description of what is allowed]"
  ON [table] FOR [operation]
  TO [role]
  USING ([boolean expression])  -- For SELECT, UPDATE, DELETE
  WITH CHECK ([boolean expression]);  -- For INSERT, UPDATE
```

### Common Patterns

#### Ownership-Based Access

```sql
-- Users can only access their own records
CREATE POLICY "Users can view own entities"
  ON entities FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own entities"
  ON entities FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());
```

#### Role-Based Access

```sql
-- Admins have full access
CREATE POLICY "Admins can view all entities"
  ON entities FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- Regular users see only their own
CREATE POLICY "Users can view own entities"
  ON entities FOR SELECT
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (
    NOT EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );
```

#### Time-Based Access

```sql
-- Users can only edit within 24 hours of creation
CREATE POLICY "Users can update recent entities"
  ON entities FOR UPDATE
  TO authenticated
  USING (
    user_id = auth.uid()
    AND created_at > now() - interval '24 hours'
  );
```

### Policy Testing

**ALWAYS** test policies with different roles:

```sql
-- Test as authenticated user
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" TO '{"sub": "user-123"}';

-- Should see own entities
SELECT * FROM entities WHERE user_id = auth.uid();

-- Should NOT see other users' entities
SELECT * FROM entities WHERE user_id != auth.uid();  -- Empty result
```

---

## Data Validation

### Zod at Boundaries

**ALWAYS** validate external data with Zod at API boundaries:

```typescript
// ✅ CORRECT — Zod validation at boundary
import { z } from "zod"

const CreateEntitySchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().optional(),
  status: z.enum(["draft", "published", "archived"]),
  metadata: z.record(z.unknown()).optional(),
})

type CreateEntityInput = z.infer<typeof CreateEntitySchema>

// In action
const _createEntityAction = createAction({
  inputSchema: CreateEntitySchema, // Automatic validation
  handler: async (input, context) => {
    // input is already validated, safe to use
    return await repository.create(input)
  },
})

// ❌ WRONG — No validation
const _createEntityAction = createAction({
  handler: async (input, context) => {
    // input could be anything!
    return await repository.create(input)
  },
})
```

### Database Constraints

**ALWAYS** add database-level constraints as defense in depth:

```sql
-- ✅ CORRECT — Multiple validation layers
CREATE TABLE entities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(name) > 0 AND length(name) <= 100),
  status text NOT NULL CHECK (status IN ('draft', 'published', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),

  -- Unique constraint
  CONSTRAINT unique_user_entity_name UNIQUE (user_id, name)
);

-- ❌ WRONG — No constraints
CREATE TABLE entities (
  id uuid PRIMARY KEY,
  name text,  -- Can be empty, null, or 10000 chars
  status text  -- Can be any value
);
```

---

## ✅ CORRECT Examples

### Complete Table with RLS

```sql
-- Table creation with RLS
CREATE TABLE entities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(name) > 0 AND length(name) <= 100),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE entities ENABLE ROW LEVEL SECURITY;

-- Indexes for performance
CREATE INDEX idx_entities_user_id ON entities(user_id);
CREATE INDEX idx_entities_created_at ON entities(created_at DESC);

-- Granular policies
CREATE POLICY "Users can view own entities"
  ON entities FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own entities"
  ON entities FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own entities"
  ON entities FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own entities"
  ON entities FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Comments for documentation
COMMENT ON TABLE entities IS 'User-created business entities';
COMMENT ON COLUMN entities.user_id IS 'Owner reference (auth.uid())';
```

### Secure Function

```sql
CREATE OR REPLACE FUNCTION get_entities_by_status(
  target_status text DEFAULT 'published'
)
RETURNS TABLE (
  id uuid,
  name text,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT e.id, e.name, e.created_at
  FROM entities e
  WHERE e.status = target_status
    AND (e.user_id = auth.uid() OR target_status = 'published');
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = '';

COMMENT ON FUNCTION get_entities_by_status IS 'Get entities filtered by status';
```

---

## ❌ WRONG Examples

### Missing RLS

```sql
-- ❌ FORBIDDEN — No RLS enabled
CREATE TABLE entities (
  id uuid PRIMARY KEY,
  name text
);
-- Missing: ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
-- Missing: CREATE POLICY ...
```

### Insecure Function

```sql
-- ❌ FORBIDDEN — No search_path, SECURITY DEFINER
CREATE OR REPLACE FUNCTION get_all_entities()
RETURNS SETOF entities AS $$
  SELECT * FROM entities;  -- Returns ALL entities to caller!
$$ LANGUAGE sql;
```

### Manual Migration

```sql
-- ❌ FORBIDDEN — Manually created migration file
-- File: supabase/migrations/20260324000000_manual_changes.sql
-- Correct: pnpm supabase:migration:new -- feature_name, then pnpm supabase db diff -o <that path>
```

---

## Scheduled maintenance (voucher expiry)

`public.expire_due_vouchers()` transitions **ACTIVATED** vouchers to **EXPIRED**
when `expires_at < now()`. It is **`SECURITY DEFINER`** and granted to
**`service_role` only** (not `authenticated`).

**Operations:** configure a nightly (or periodic) job in the Supabase project
that runs:

```sql
SELECT public.expire_due_vouchers();
```

Use **Supabase Dashboard → Database → Scheduled triggers** (or **pg_cron** on
the project, if enabled) with the **service role** context required for that
function. Do not expect logged-in users to call it.

---

## Related Documents

- [Backend](./backend.md) - Backend standards and repository pattern
- [System layers & boundaries](./system.md) - Overall architecture overview
