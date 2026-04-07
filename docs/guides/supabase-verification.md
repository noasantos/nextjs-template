# Supabase Configuration Verification

**Purpose:** Manual verification steps for Supabase project configuration
required for auth + data layer compliance.

---

## SECTION 8 — JWT Expiry Configuration

### Why This Matters

`getClaims()` does not verify token revocation with the Auth server. A banned or
deleted user whose token has not expired retains PHI access for the full JWT
TTL. Setting JWT expiry to 900s (15 minutes) limits the breach window to 15
minutes maximum.

### Verification Steps

1. **Navigate to Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project

2. **Open JWT Settings**
   - Navigate to: **Project Settings** → **Auth** → **JWT Settings**
   - Or directly:
     https://supabase.com/dashboard/project/[YOUR_PROJECT_ID]/settings/auth

3. **Verify Access Token Expiry**
   - Find: **Access token expiry time** (in seconds)
   - **Required value:** `900` (15 minutes)
   - **Default value:** `3600` (1 hour) — ❌ INCORRECT

4. **Update if Needed**
   - If not set to 900:
     - Click **Edit** or the input field
     - Change value to `900`
     - Click **Save**

5. **Verify Auto-Refresh Works**
   - No code changes required — Supabase SDK auto-refreshes before expiry
   - Test: Log in, wait 14 minutes, verify session still active

### Screenshot Required

Take a screenshot showing:

- Project Settings → Auth → JWT Settings page
- Access token expiry time = 900
- Save the screenshot to: `docs/verification/jwt-expiry-900s.png`

### Checklist

- [ ] Access token expiry set to 900s
- [ ] Screenshot saved to `docs/verification/`
- [ ] Auto-refresh tested (no code changes needed)

---

## SECTION 6 — RLS Policy Verification

### Why This Matters

RLS policies enforce row-level security at the database level. Incorrect
policies cause:

- **Security vulnerabilities** (unauthorized access)
- **Performance issues** (full table scans instead of index usage)
- **Compliance violations** (HIPAA, SOC2)

### Verification Query

Run this query in the Supabase SQL Editor to verify RLS performance:

```sql
-- Set up test session as authenticated user
SET session role authenticated;
SET request.jwt.claims TO '{"role":"authenticated","sub":"YOUR-TEST-UUID"}';

-- Verify query plan shows InitPlan (confirms (SELECT auth.uid()) caching)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM psychologist_patients
WHERE psychologist_id = (SELECT auth.uid());

-- Reset session
SET session role postgres;
```

**Expected Output:**

- Look for **"InitPlan"** node in the output
- This confirms `(SELECT auth.uid())` is evaluated once per statement (not per
  row)
- Should show **Index Scan** or **Index Only Scan** (not Seq Scan)

### Policy Checklist

Review all RLS policies in Supabase Dashboard → **Authentication** →
**Policies**:

#### All Policies Must Have:

- [ ] `TO authenticated` clause (prevents anon execution)
- [ ] `auth.uid()` wrapped as `(SELECT auth.uid())` (enables initPlan caching)
- [ ] Custom functions wrapped as `(SELECT fn())` (e.g.,
      `(SELECT private.is_admin())`)
- [ ] Btree index on every column used in USING clause

#### UPDATE Policies Must Have:

- [ ] Both `USING` (existing row check) AND `WITH CHECK` (incoming row check)
- [ ] Corresponding SELECT policy (UPDATE without SELECT doesn't work)

#### SECURITY DEFINER Functions Must:

- [ ] Be in `private` schema (not `public`)
- [ ] Use `SECURITY DEFINER` with `SET search_path = public`

### Migration Review

Check existing migrations for compliance:

```bash
# Search for CREATE POLICY statements
grep -r "CREATE POLICY" supabase/migrations/*.sql

# Search for SECURITY DEFINER functions
grep -r "SECURITY DEFINER" supabase/migrations/*.sql
```

**Review each migration for:**

- [ ] `TO authenticated` clause present
- [ ] `(SELECT auth.uid())` wrapping
- [ ] `USING` and `WITH CHECK` on UPDATE policies
- [ ] `private.` schema prefix on SECURITY DEFINER functions

### Index Verification

Verify indexes exist on ownership columns:

```sql
-- List all indexes on tenant-scoped tables
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('psychologist_patients', 'appointments', 'session_notes')
ORDER BY tablename, indexname;
```

**Expected:**

- [ ] `idx_psychologist_patients_psychologist_id` on
      `psychologist_patients(psychologist_id)`
- [ ] `idx_appointments_psychologist_id` on `appointments(psychologist_id)`
- [ ] `idx_session_notes_psychologist_id` on `session_notes(psychologist_id)`

### Fix Script (If Needed)

If policies need updating, use this template:

```sql
-- 1. Create index (if missing)
CREATE INDEX IF NOT EXISTS idx_patients_psychologist_id
  ON psychologist_patients USING btree (psychologist_id);

-- 2. Drop old policy (if exists)
DROP POLICY IF EXISTS "patients_select_own" ON psychologist_patients;

-- 3. Create compliant policy
CREATE POLICY "patients_select_own"
  ON psychologist_patients FOR SELECT TO authenticated
  USING (psychologist_id = (SELECT auth.uid()));

-- 4. Move SECURITY DEFINER function to private schema (if needed)
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT COALESCE(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false
  );
$$;
```

### Documentation

Save verification results to:

- `docs/verification/rls-policy-review.md`
- Include query outputs
- List any policies that need fixing
- Create migration if changes needed

---

## Next Steps After Verification

1. **Complete JWT Expiry Verification**
   - [ ] Set to 900s in dashboard
   - [ ] Save screenshot

2. **Complete RLS Policy Review**
   - [ ] Run verification query
   - [ ] Review all policies
   - [ ] Create migration if fixes needed

3. **Update This Document**
   - [ ] Add verification date
   - [ ] Add reviewer name
   - [ ] Link to screenshots
   - [ ] Link to migration files (if any)

---

**Last Updated:** 2026-04-07  
**Next Review:** Before production deployment  
**Owner:** Engineering Team
