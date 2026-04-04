# Anti-Patterns Catalogue

These patterns are forbidden. Each entry includes detection method and preferred
alternative.

---

## BAD-001: God Components

**Pattern:** Components exceeding 250 lines with multiple responsibilities.

**Why Harmful:** High cognitive load, side-effect coupling, poor testability.

**Preferred Alternative:** Extract into container + presentational pieces.

**Detection:**

- ESLint `max-lines` warns at 250, errors at 300
- Manual review: can you explain what this component does in one sentence?

**Example:**

```typescript
// ❌ BAD: 400 lines doing data fetching, state management, and rendering
function UserProfile() { /* ... */ }

// ✅ GOOD: Split into focused units
function UserProfile() { return <UserProfileView user={user} />; }
function UserProfileView({ user }) { /* presentation only */ }
function useUserProfile(userId) { /* data fetching only */ }
```

---

## BAD-002: Barrel Files

**Pattern:** `index.ts` files that re-export from other files.

**Why Harmful:** Hidden dependencies, poor tree-shaking, unclear import sources.

**Preferred Alternative:** Subpath exports in `package.json`.

**Detection:**

```bash
# Find barrel files
find . -name "index.ts" -exec grep -l "export \* from" {} \;
```

**Example:**

```typescript
// ❌ BAD: packages/ui/src/index.ts
export * from "./components/button";
export * from "./components/input";

// ✅ GOOD: packages/ui/package.json
{
  "exports": {
    "./components/button": "./src/components/button.tsx",
    "./components/input": "./src/components/input.tsx"
  }
}
```

---

## BAD-003: App-Local Data Abstractions

**Pattern:** Creating `apps/*/lib/db/actions/*` or `apps/*/lib/repositories/*`.

**Why Harmful:** Duplicated boundaries, drift from package implementations.

**Preferred Alternative:** Import from `@workspace/supabase-data` (or the
relevant `@workspace/*` package) near the feature.

**Detection:**

```bash
# Find app-local data abstractions
find apps -path "*/lib/db/actions/*" -o -path "*/lib/repositories/*"
```

**Example:**

```typescript
// ✅ GOOD: Import from package
import { useUser } from "@workspace/supabase-data/hooks/..."

// ❌ BAD: apps/web/lib/db/user.actions.ts
export async function getUser(id: string) {
  /* ... */
}
```

---

## BAD-004: Utility Dump Files

**Pattern:** Single files with dozens of unrelated utility functions.

**Why Harmful:** Low discoverability, poor ownership, unclear responsibilities.

**Preferred Alternative:** Domain-scoped utility modules.

**Detection:**

- File contains >10 exported functions
- Functions have unrelated names (e.g., `formatDate`, `calculateTax`,
  `validateEmail`)

**Example:**

```typescript
// ❌ BAD: lib/utils.ts with 50 unrelated functions
export function formatDate() {}
export function calculateTax() {}
export function validateEmail() {}

// ✅ GOOD: Domain-scoped modules
export function formatDate() {} // lib/date/format.ts
export function calculateTax() {} // lib/finance/tax.ts
export function validateEmail() {} // lib/validation/email.ts
```

---

## BAD-005: Implicit Shared Context State

**Pattern:** Using React Context for state that should be local.

**Why Harmful:** Hidden runtime dependencies, unclear data flow.

**Preferred Alternative:** Local state first; context only for true globals
(theme, auth).

**Detection:**

- Context created for single-feature state
- Context providers nested deep in component tree

**Example:**

```typescript
// ❌ BAD: Context for single-component state
const UserContext = createContext()
function UserProfile() {
  const [user, setUser] = useContext(UserContext)
}

// ✅ GOOD: Local state
function UserProfile() {
  const [user, setUser] = useState()
}
```

---

## BAD-006: Happy-Path-Only Tests

**Pattern:** Tests that only verify success scenarios.

**Why Harmful:** False confidence, untested error handling.

**Preferred Alternative:** Test success, error, and loading states.

**Detection:**

- Test file has no `describe("error handling")` blocks
- No tests for edge cases or invalid inputs

**Example:**

```typescript
// ❌ BAD: Only tests success
test("loads user data", () => {
  /* ... */
})

// ✅ GOOD: Tests all paths
test("loads user data on success", () => {
  /* ... */
})
test("shows error on failure", () => {
  /* ... */
})
test("shows loading state", () => {
  /* ... */
})
```

---

## BAD-007: Stale AGENTS Handbook

**Pattern:** AI instructions become outdated as codebase evolves.

**Why Harmful:** AI agents follow incorrect patterns, instruction drift.

**Preferred Alternative:** TOC-style AGENTS.md with linked deep docs.

**Detection:**

- AGENTS.md >120 lines (becomes unmaintainable)
- Links in AGENTS.md point to non-existent files

**Enforcement:** Keep AGENTS.md under 120 lines; use links for details.

---

## BAD-008: Type Assertions Without Parsing

**Pattern:** Using `as Type` on API responses or user input.

**Why Harmful:** Runtime type mismatch risk, schema drift.

**Preferred Alternative:** Zod parse at boundaries.

**Detection:**

```bash
# Find type assertions
grep -r "as [A-Z]" src --include="*.ts" --include="*.tsx"
```

**Example:**

```typescript
// ❌ BAD
const user = response as User

// ✅ GOOD
const user = UserSchema.parse(response)
```

---

## BAD-009: Undocumented Frozen Code

**Pattern:** Code that should not be changed without explicit rationale.

**Why Harmful:** Unsafe refactors, breaking changes in shared code.

**Preferred Alternative:** `// FROZEN: <reason>` comments with rationale.

**Detection:** Manual review of shared packages.

**Example:**

```typescript
// FROZEN: This adapter is used by 5 apps. Changing the interface breaks all consumers.
// Contact: @team-lead before modifying.
export function createAdapter() {
  /* ... */
}
```

---

## BAD-010: Directory Naming Drift

**Pattern:** Inconsistent directory names across routes/apps.

**Why Harmful:** Unclear placement for new code, poor discoverability.

**Preferred Alternative:** `_hooks/_utils/_components` convention for private
directories.

**Detection:**

```bash
# Find non-standard directory names
find src -type d -name "*hooks*" ! -name "_hooks"
```

**Example:**

```typescript
// ❌ BAD: Inconsistent naming
src/routes/dashboard/hooks/      // Missing underscore
src/routes/admin/_hooks/         // Has underscore

// ✅ GOOD: Consistent convention
src/routes/dashboard/_hooks/
src/routes/admin/_hooks/
```

---

## BAD-011: Global Supabase Client

**Pattern:** Creating Supabase server client at module scope.

**Why Harmful:** Leaks authentication state between requests in serverless
environments.

**Preferred Alternative:** Fluid compute - new client per request inside
handler.

**Detection:**

```bash
# Find module-scope Supabase clients
grep -r "createServerClient" --include="*.ts" | grep -v "export async"
```

**Example:**

```typescript
// ❌ BAD: Module scope = shared between requests!
const supabase = createServerClient(...);
export async function myAction() {
  const { data } = await supabase.auth.getClaims(); // Stale cookies!
}

// ✅ GOOD: New client per invocation
export async function myAction() {
  const supabase = await createServerAuthClient();
  const { data } = await supabase.auth.getClaims();
}
```

**See:**
[BACKEND.md → Authentication](../architecture/backend.md#authentication)

---

## BAD-012: getSession() for Server Authorization

**Pattern:** Using `getSession()` for server-side auth decisions.

**Why Harmful:** `getSession()` reads cookie without verifying JWT. Unsafe for
security decisions.

**Preferred Alternative:** Always use `getClaims()` (verifies JWT via cached
JWKS).

**Detection:**

```bash
# Find getSession() usage in server code
grep -r "getSession()" --include="*.ts" --include="*.tsx" | grep -v "node_modules"
```

**Example:**

```typescript
// ❌ BAD: Not verified, unsafe for auth
const {
  data: { session },
} = await supabase.auth.getSession()
const userId = session.user.id // Could be tampered!

// ✅ GOOD: Verified via JWKS
const supabase = await createServerAuthClient()
const {
  data: { claims },
} = await supabase.auth.getClaims()
const userId = claims.sub // Verified!
```

**See:**
[BACKEND.md → Authentication](../architecture/backend.md#authentication)

---

## BAD-013: Raw Queries Outside Repositories

**Pattern:** Using `supabase.from().select()` outside repository infrastructure
layer.

**Why Harmful:** Database types leak to domain, business logic scattered, poor
testability.

**Preferred Alternative:** Repository pattern with DTOs and mappers.

**Detection:**

```bash
# Find raw queries in actions/components
grep -r "\.from(" --include="*.ts" | grep -v "infrastructure/repositories"
```

**Example:**

```typescript
// ❌ BAD: Raw query in action
export const getEntityAction = createAction({
  handler: async (input, context) => {
    const { data } = await context.supabase.from("entities").select("*") // Database types leak!
    return ok(data)
  },
})

// ✅ GOOD: Repository with DTO
export const getEntityAction = createAction({
  handler: async (input, context) => {
    const repo = new EntitySupabaseRepository(context.supabase)
    return await repo.findById(input.id) // Returns EntityDTO
  },
})
```

**See:**
[BACKEND.md → Repository Pattern](../architecture/backend.md#repository-pattern)

---

## BAD-014: Tables Without RLS

**Pattern:** Creating tables without enabling Row Level Security.

**Why Harmful:** Security vulnerability, anyone can access all data.

**Preferred Alternative:** RLS-first design - enable RLS on table creation.

**Detection:**

```bash
# Find tables without RLS in migrations
grep -r "CREATE TABLE" --include="*.sql" | grep -v "ENABLE ROW LEVEL SECURITY"
```

**Example:**

```sql
-- ❌ BAD: No RLS enabled
CREATE TABLE entities (
  id uuid PRIMARY KEY,
  name text
);

-- ✅ GOOD: RLS enabled + policies
CREATE TABLE entities (...);
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own" ON entities FOR SELECT
  TO authenticated USING (user_id = auth.uid());
```

**See:**
[DATABASE.md → RLS-First Design](../architecture/database.md#rls-first-design)

---

## BAD-015: Manual Migration Files (CRITICAL - PROHIBITED)

**Pattern:** Creating migration files under `supabase/migrations/` without
`pnpm supabase:migration:new`, or using `pnpm supabase db diff -f <name>` as the
**only** step (unstamped file).

**Why Harmful:** Schema drift, missing stamped metadata, inconsistent review —
**CAN BREAK PRODUCTION DEPLOYMENTS**.

**Preferred Alternative:** `pnpm supabase:migration:new -- <name>`, then
`pnpm supabase db diff -o <that path>` (and `pnpm supabase:migration:stamp` if
the header was overwritten).

**Detection:**

```bash
# Migrations missing the stamped header (heuristic)
rg -L "migration-created-via" supabase/migrations/*.sql
```

**Example:**

```bash
# ❌ BAD: inventing the file path
# echo "..." > supabase/migrations/20260324000000_manual_changes.sql

# ❌ BAD: db diff --file as sole create (no migration:new stamp)
# pnpm supabase db diff -f create_users_table

# ✅ GOOD: stamped file + diff into same path
pnpm supabase:migration:new -- create_users_table
pnpm supabase db diff -o supabase/migrations/YYYYMMDDHHMMSS_create_users_table.sql
```

**⚠️ CRITICAL WARNING FOR AI AGENTS:**

**YOU ARE STRICTLY PROHIBITED FROM:**

1. Creating files in `supabase/migrations/` without
   `pnpm supabase:migration:new`
2. Providing SQL to paste into a hand-made migration path
3. Suggesting `db diff -f` / `--file` alone as the create step
4. Bypassing
   [docs/guides/migration-workflow.md](../docs/guides/migration-workflow.md)

**YOU MUST ALWAYS:**

1. Instruct: local DDL → `pnpm supabase:migration:new -- <name>` →
   `pnpm supabase db diff -o <path>`
2. Review the file; restore the header with `pnpm supabase:migration:stamp` if
   needed
3. Commit the migration file

**This is a NON-NEGOTIABLE rule. Violations can break production.**

**See:** [DATABASE.md → Migrations](../architecture/database.md#migrations)

---

## BAD-016: Insecure Database Functions

**Pattern:** Functions without `SECURITY INVOKER` or `search_path = ''`.

**Why Harmful:** Schema hijacking risk, privilege escalation.

**Preferred Alternative:** Always use `SECURITY INVOKER SET search_path = ''`.

**Detection:**

```bash
# Find insecure functions in migrations
grep -r "CREATE.*FUNCTION" --include="*.sql" | grep -v "SECURITY INVOKER"
grep -r "CREATE.*FUNCTION" --include="*.sql" | grep -v "search_path"
```

**Example:**

```sql
-- ❌ BAD: Insecure function
CREATE OR REPLACE FUNCTION get_entity(id uuid)
RETURNS entities AS $$
  SELECT * FROM entities WHERE id = id;
$$ LANGUAGE sql;  -- SECURITY DEFINER by default!

-- ✅ GOOD: Secure function
CREATE OR REPLACE FUNCTION get_entity_by_id(target_id uuid)
RETURNS TABLE (id uuid, name text) AS $$
  SELECT e.id, e.name FROM entities e WHERE e.id = target_id;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = '';
```

**See:**
[DATABASE.md → Database Functions](../architecture/database.md#database-functions)

---

## BAD-017: Skipping TDD or Migration-Safe Order

**Pattern:** Implementing repositories, actions, or UI before failing tests and
contracts; or hand-writing migration SQL / editing `supabase/migrations/` to
“match” tests.

**Why Harmful:** False confidence, schema drift, RLS mistakes, production
incidents (with manual migrations).

**Preferred Alternative:** [TDD.md](../architecture/tdd.md) lifecycle;
[TESTING.md](../architecture/testing.md) for suites;
[GR-016](./golden-rules.md#gr-016-tdd-process-compliance).

**Detection:** PR checklist; missing tests for new behavior; migration files not
CLI-generated; RLS-only verified via mocks.

---

## BAD-018: Wrong tier for business documentation

**Pattern:** Putting **product or business** material in the **monorepo root**
`docs/`, or putting **cross-app** business docs only under
**`apps/<app>/docs/`** (fragmented), or putting **template standards** under
`apps/docs/`.

**Why Harmful:** Forks inherit noise; LLMs and contributors cannot find domain
truth; engineering vs product boundaries blur.

**Preferred Alternative:** Three tiers — **Level 1** root `docs/` = template
only; **Level 2** `apps/docs/` = business **across apps**; **Level 3**
`apps/<app>/docs/` = **one app’s** domain. See
[GR-019](./golden-rules.md#gr-019-three-level-documentation-layout).

**Detection:** Product glossary or multi-app flows only in per-app `docs/`;
stakeholder specs in root `docs/`; missing `apps/docs/AGENTS.md` when the
product has cross-app docs.
