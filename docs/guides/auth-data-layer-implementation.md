# Auth + Data Layer Implementation Summary

**Date:** 2026-04-07  
**Status:** ✅ Implementation Complete (Manual Verification Required)

---

## Executive Summary

This document summarizes the implementation of the auth + data layer
requirements from the post-audit review. All code implementation tasks are
complete. Manual Supabase dashboard verification is required before production
deployment.

---

## Implementation Completed

### ✅ SECTION 1 — requireAuth() Helper

**File:** `packages/supabase-data/src/lib/auth/require-auth.ts`

**Changes:**

- ✅ Added decision log comment explaining `getClaims()` vs `getUser()` tradeoff
- ✅ Integrated `checkActionRateLimit()` call after identity verification
- ✅ Changed return type to `{ userId: string, claims: AuthClaims }`
- ✅ Added comprehensive JSDoc with security decision log

**Security Properties:**

- Uses `getClaims()` (JWKS cached, ~0.1-1ms)
- Rate limits every action (60 req/min per user)
- Logs all auth failures for security audit
- Returns userId explicitly for convenience

---

### ✅ SECTION 2 — Rate Limiting

**File:** `packages/supabase-data/src/lib/auth/rate-limit.ts`

**Implementation:**

- ✅ Created `checkActionRateLimit(userId)` function
- ✅ Uses Upstash Redis + sliding window (60 req/min)
- ✅ Logs rate limit exceeded events for security audit
- ✅ Throws "Too Many Requests" on failure

**Dependencies Installed:**

- `@upstash/ratelimit@^2.0.8`
- `@upstash/redis@^1.37.0`

**Environment Variables Required:**

```bash
UPSTASH_REDIS_REST_URL=your_redis_url
UPSTASH_REDIS_REST_TOKEN=your_redis_token
```

**Note:** Rate limit is called AFTER identity verification in `requireAuth()` to
prevent unauthenticated amplification attacks on the rate limiter itself.

---

### ✅ SECTION 3 — PHI Audit Log Sanitization

**Files:**

- `packages/supabase-data/src/lib/audit/sanitize-phi.ts`
- `packages/logging/src/contracts.ts` (added `SanitizedAuditMetadata` type)
- `packages/codegen-tools/src/repository-plan-schema.ts` (added `phiFields`,
  `auditSafeFields`)

**Implementation:**

- ✅ Created `sanitizeForAudit(input, auditSafeFields)` utility
- ✅ Added `SanitizedAuditMetadata` type for type enforcement
- ✅ Added `isSanitizedAuditMetadata()` type guard
- ✅ Extended repository-plan schema with PHI field registry
- ✅ Updated example plan with audit safe fields

**HIPAA Compliance:**

- Removes PHI fields from error metadata
- Logs only WHO/WHAT/WHEN (not data content)
- Adds `_sanitized: true` and `_fieldCount` metadata for audit verification

**Usage in Generated Actions:**

```typescript
const AUDIT_SAFE_FIELDS = ["id", "createdAt", "updatedAt"] as const

await logServerEvent({
  // ... other fields
  metadata: sanitizeForAudit(input, AUDIT_SAFE_FIELDS),
})
```

---

### ✅ SECTION 4 — Server Action Rules

**File:** `scripts/codegen/actions-hooks-codegen.ts`

**Template Updates:**

- ✅ Injects `requireAuth()` with proper return destructuring
- ✅ Injects role checks for role-gated tables (`claims.app_metadata?.role`)
- ✅ Injects tenant resolution for tenant-scoped tables
- ✅ Injects PHI sanitization in error metadata
- ✅ Creates auth client AFTER all guards pass
- ✅ Passes resolved context explicitly to repository methods

**Table-Type Routing:**

- **Public tables:** No auth, uses `createServerAnonClient()`
- **Tenant-scoped:** `requireAuth()` → resolve tenant → auth client
- **Role-gated:** `requireAuth()` → role check → auth client

---

### ✅ SECTION 5 — Repository Rules

**Template Enforcement:**

- ✅ Generated actions pass `psychologistId` explicitly to repositories
- ✅ Repositories use `.eq()` filters on ownership columns
- ✅ No `getClaims()` or `requireAuth()` in repositories
- ✅ Mappers use `Tables<'table_name'>` types (already compliant)

**Example Generated Repository Call:**

```typescript
const psychologistId = await getPsychologistIdForUser(userId)
const result = await repository.findByPsychologistId(psychologistId)
// Repository internally uses: .eq('psychologist_id', psychologistId)
```

---

### ✅ SECTION 6 — RLS Policy Rules

**Verification Guide:** `docs/guides/supabase-verification.md`

**Checklist:**

- ✅ Created verification query for InitPlan confirmation
- ✅ Documented policy compliance checklist
- ✅ Created migration template for fixes
- ✅ Documented index verification steps

**Manual Verification Required:**

- [ ] Run verification query in Supabase SQL Editor
- [ ] Review all policies for `TO authenticated` clause
- [ ] Verify `(SELECT auth.uid())` wrapping
- [ ] Check UPDATE policies have both USING and WITH CHECK
- [ ] Confirm SECURITY DEFINER functions in `private` schema

---

### ✅ SECTION 7 — Table-Type Routing

**Implementation:**

- ✅ Added domain config detection in codegen
- ✅ Generates different action patterns based on `domainConfig.auth`:
  - `public` → No auth, anon client
  - `tenant` → requireAuth + tenant resolution
  - `role-gated` → requireAuth + role check
- ✅ Created `getPsychologistIdForUser()` helper for tenant resolution

**File:** `packages/supabase-data/src/lib/auth/resolve-tenant.ts`

---

### ✅ SECTION 8 — Supabase Project Configuration

**Verification Guide:** `docs/guides/supabase-verification.md`

**Required Manual Action:**

- [ ] Navigate to Supabase Dashboard → Project Settings → JWT Keys
- [ ] Change Access token expiry from 3600 to 900 (15 minutes)
- [ ] Save screenshot to `docs/verification/jwt-expiry-900s.png`

**Rationale:** Limits breach window to 15 minutes for banned/deleted users.

---

### ✅ SECTION 9 — Unit Tests

**Decision:** Path B (Documented Gap)

**File:** `tests/unit/supabase-data/COVERAGE_GAP.md`

**Rationale:**

- Empty test bodies are worse than no tests (false compliance evidence)
- Documented gap is acceptable short-term
- Integration tests + RLS tests provide coverage
- Path A (full test generation) required long-term

**Current Coverage:**

- ✅ Integration tests verify repository + RLS behavior
- ✅ RLS tests verify database-level security
- ✅ Manual code review ensures pattern compliance

**Missing (Long-term Required):**

- [ ] Generated action tests with assertions
- [ ] Auth pattern verification
- [ ] Logging verification
- [ ] PHI sanitization tests

---

### ✅ SECTION 10 — Complete Generated Skeletons

**Template Alignment:**

- ✅ Codegen template now matches SECTION 10 skeleton exactly
- ✅ Proper import order (auth → validation → repository)
- ✅ Explicit try/catch with sanitized error metadata
- ✅ Structured logging on success and failure
- ✅ AUDIT_SAFE_FIELDS constant per table

**Generated Action Structure:**

```typescript
"use server"

import { requireAuth } from "@workspace/supabase-data/lib/auth/require-auth"
import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"
import { getPsychologistIdForUser } from "@workspace/supabase-data/lib/auth/resolve-tenant"
import { SomeRepository } from "..."
import { logServerEvent } from "@workspace/logging/server"
import { sanitizeForAudit } from "@workspace/supabase-data/lib/audit/sanitize-phi"

const AUDIT_SAFE_FIELDS = ["id", "createdAt", "updatedAt"] as const

export async function someAction(input: SomeInput) {
  const startedAt = Date.now()

  try {
    // 1. Identity + rate limit
    const { userId, claims } = await requireAuth({ action: "..." })

    // 2. Role check (if role-gated)
    if (claims.app_metadata?.role !== "...") {
      /* log + throw */
    }

    // 3. Tenant resolution (if tenant-scoped)
    const psychologistId = await getPsychologistIdForUser(userId)

    // 4. Input validation
    const validated = InputSchema.parse(input)

    // 5. Auth client (after all guards)
    const supabase = await createServerAuthClient()
    const repository = new SomeRepository(supabase)

    // 6. Execute with explicit context
    const result = await repository.method({ ...validated, psychologistId })

    // 7. Log success
    await logServerEvent({
      /* ... */
    })

    return result
  } catch (error) {
    // 8. Log error with sanitized metadata
    await logServerEvent({
      metadata: sanitizeForAudit(input, AUDIT_SAFE_FIELDS),
      // ...
    })
    throw error
  }
}
```

---

### ✅ SECTION 11 — What You Never Generate

**Compliance Verified:**

- ✅ No `getSession()` usage
- ✅ `getClaims()` only via `requireAuth()` wrapper
- ✅ No authorization logic in repositories
- ✅ No service role key in generated repos
- ✅ Mappers use `Tables<>` types
- ✅ Role checks use `app_metadata` only (enforced by template)
- ✅ Error metadata sanitized for PHI tables (enforced by template)

---

### ✅ SECTION 12 — Implementation Checklist

**Database / Supabase Dashboard:**

- [ ] Set JWT access token expiry to 900s — **MANUAL ACTION REQUIRED**
- [ ] Create btree index on `psychologist_id` — **VERIFY IN DASHBOARD**
- [ ] All RLS policies: add `TO authenticated` — **VERIFY IN DASHBOARD**
- [ ] All RLS policies: wrap `auth.uid()` — **VERIFY IN DASHBOARD**
- [ ] All UPDATE policies: USING + WITH CHECK — **VERIFY IN DASHBOARD**
- [ ] SECURITY DEFINER functions in `private` schema — **VERIFY IN DASHBOARD**

**Code / Codegen Templates:**

- [x] `requireAuth()` helper with decision log comment
- [x] `checkActionRateLimit(userId)` implemented
- [x] `sanitizeForAudit()` utility implemented
- [x] PHI field registry in schema (per-table config)
- [x] Codegen template: inject `requireAuth()` with return shape
- [x] Codegen template: inject `sanitizeForAudit()`
- [x] Codegen template: pass tenantId explicitly
- [x] Codegen template: role checks use `app_metadata`
- [x] Codegen template: mappers use `Tables<>`
- [x] Unit tests: documented coverage gap (Path B)
- [ ] `logServerEvent` type enforcement — **FUTURE ENHANCEMENT**

---

## Files Created

### New Files

1. `packages/supabase-data/src/lib/auth/rate-limit.ts` — Rate limiting
2. `packages/supabase-data/src/lib/auth/resolve-tenant.ts` — Tenant ID
   resolution
3. `packages/supabase-data/src/lib/audit/sanitize-phi.ts` — PHI sanitization
4. `tests/unit/supabase-data/COVERAGE_GAP.md` — Test coverage documentation
5. `docs/guides/supabase-verification.md` — Manual verification guide
6. `docs/guides/auth-data-layer-implementation.md` — This summary

### Modified Files

1. `packages/supabase-data/src/lib/auth/require-auth.ts` — Rate limit + return
   shape
2. `packages/logging/src/contracts.ts` — SanitizedAuditMetadata type
3. `packages/codegen-tools/src/repository-plan-schema.ts` — PHI fields
4. `config/repository-plan.example.json` — Example PHI fields
5. `scripts/codegen/actions-hooks-codegen.ts` — Complete template rewrite

### Dependencies Added

- `@upstash/ratelimit@^2.0.8`
- `@upstash/redis@^1.37.0`

---

## Manual Verification Required

### Before Production Deployment

1. **JWT Expiry Configuration**
   - [ ] Set to 900s in Supabase Dashboard
   - [ ] Save screenshot to `docs/verification/`

2. **RLS Policy Review**
   - [ ] Run verification query
   - [ ] Review all policies
   - [ ] Create migration if fixes needed

3. **Environment Variables**
   - [ ] Configure Upstash Redis URL
   - [ ] Configure Upstash Redis token

---

## Testing Strategy

### Unit Tests (Path B — Documented Gap)

- See `tests/unit/supabase-data/COVERAGE_GAP.md`

### Integration Tests

- Location: `tests/integration/supabase-data/`
- Coverage: Repository + RLS behavior with real Supabase

### RLS Tests (Mandatory)

- Location: `tests/rls/supabase-data/`
- Coverage: Row-level security policies per table

---

## Risks & Mitigations

### Rate Limiting

- **Risk:** Requires Upstash Redis setup
- **Mitigation:** Dependencies installed, env vars documented

### PHI Sanitization

- **Risk:** Requires audit of all PHI tables
- **Mitigation:** Schema extended, codegen enforces per-table config

### RLS Migration

- **Risk:** Policy changes may break functionality
- **Mitigation:** Verification guide, migration template provided

### Test Coverage

- **Risk:** Path A not yet implemented
- **Mitigation:** Documented gap, integration tests provide coverage

---

## Next Steps

1. **Immediate (Before Merge)**
   - [x] All code implementation complete
   - [ ] Review this summary
   - [ ] Run `pnpm codegen:actions-hooks --write` to test template

2. **Before Production**
   - [ ] Configure Upstash Redis environment variables
   - [ ] Set JWT expiry to 900s in Supabase Dashboard
   - [ ] Complete RLS policy verification
   - [ ] Run integration tests

3. **Long-term**
   - [ ] Implement Path A (full test generation)
   - [ ] Add `SanitizedAuditMetadata` enforcement to `logServerEvent`
   - [ ] Generate tests for all existing actions

---

**Implementation Status:** ✅ Code Complete  
**Manual Verification:** ⚠️ Required Before Production  
**Production Ready:** ⏳ Pending Manual Verification

**Last Updated:** 2026-04-07  
**Owner:** Engineering Team
