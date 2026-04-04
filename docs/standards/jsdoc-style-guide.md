# JSDoc Style Guide

**All code MUST follow this JSDoc documentation standard.**

## Why

Consistent documentation:

- Helps AI agents understand code intent
- Provides inline usage examples
- Documents security considerations
- Explains performance characteristics
- Improves maintainability

## Structure

### File Header

Every file MUST start with a JSDoc block containing:

```typescript
/**
 * [Brief description of what this file does]
 *
 * [Extended description with key features, use cases, etc.]
 *
 * ## Section Headers (if needed)
 *
 * Use markdown headers for organizing long descriptions.
 *
 * @returns [What this returns]
 * @security [Security considerations if applicable]
 * @performance [Performance characteristics if applicable]
 * @see {@link relatedFunction} - Related functionality
 *
 * @module @workspace/package/path/to-file
 */
```

### Function Documentation

Every exported function MUST have:

````typescript
/**
 * [Function name] - [Brief description]
 *
 * [Extended description explaining what it does and why]
 *
 * ## When to Use (if applicable)
 *
 * **Use this when:**
 * - ✅ [Use case 1]
 * - ✅ [Use case 2]
 *
 * **Do NOT use when:**
 * - ❌ [When not to use 1]
 * - ❌ [When not to use 2]
 *
 * ## Usage
 *
 * ```typescript
 * // Code example showing typical usage
 * const result = myFunction(params)
 * ```
 *
 * ## Examples (if multiple scenarios)
 *
 * ### Basic Example
 *
 * ```typescript
 * // Simple use case
 * ```
 *
 * ### Advanced Example
 *
 * ```typescript
 * // Complex use case
 * ```
 *
 * @param paramName - [Description of parameter]
 * @param [optionalParam] - [Description, mark optional with brackets]
 * @returns [What this returns, include type if complex]
 * @throws [ErrorType] - [When this error is thrown]
 * @security [Security warnings if applicable]
 * @performance [Performance notes if applicable]
 * @deprecated [Reason, suggest alternative]
 * @see {@link relatedFunction} - [What it's related to]
 *
 * @module @workspace/package/path/to-function
 */
export function myFunction(paramName: string): ReturnType {
  // Implementation
}
````

## Tags Reference

### Required Tags

**@module** (ALWAYS required)

```typescript
/**
 * @module @workspace/supabase-auth/session/get-claims
 */
```

**@returns** (for functions that return values)

```typescript
/**
 * @returns JWT claims object or null if not authenticated
 */
```

### Optional Tags

**@security** (when security implications exist)

```typescript
/**
 * @security Server-side only - never expose to browser
 * @warning Bypasses Row Level Security
 */
```

**@performance** (when performance characteristics matter)

```typescript
/**
 * @performance Makes DB call - use getClaims() for simple checks
 * @performance Cached with React.cache() - deduplicated per request
 */
```

**@throws** (when function can throw errors)

```typescript
/**
 * @throws Error if environment variables are missing or invalid
 */
```

**@deprecated** (when function is deprecated)

```typescript
/**
 * @deprecated Use getClaims() for auth checks
 * @see {@link getClaims} - Faster alternative
 */
```

**@see** (for related functionality)

```typescript
/**
 * @see {@link getUser} - Get full user profile
 * @see {@link getSession} - Get session with tokens
 */
```

## Examples by Category

### Authentication Functions

````typescript
/**
 * Get JWT claims from authenticated user
 *
 * This is the **PRIMARY method for server authentication**.
 * Uses JWKS cache - typically 0 network calls after first request.
 *
 * ## Performance
 *
 * | Call | Network Calls | Latency |
 * |------|--------------|---------|
 * | First | 1 (JWKS fetch) | ~50ms |
 * | Subsequent | 0 (cache hit) | <1ms |
 *
 * ## Usage
 *
 * ```typescript
 * import { getClaims } from "@workspace/supabase-auth/session"
 *
 * export async function myServerAction() {
 *   const claims = await getClaims()
 *   if (!claims?.sub) throw new Error("Unauthorized")
 * }
 * ```
 *
 * @returns JWT claims object or null if not authenticated
 * @security Preferred over getUser() for simple auth checks
 * @performance Cached with React.cache() - deduplicated per request
 *
 * @module @workspace/supabase-auth/session/get-claims
 */
````

### Environment Functions

```typescript
/**
 * Get validated server environment variables
 *
 * These variables **MUST NEVER be exposed to the browser**.
 * They contain sensitive server credentials with full database access.
 *
 * ## Security Warning
 *
 * ⚠️ **CRITICAL**: These variables are **server-only** and must:
 *
 * - ✅ Only be used in server-side code
 * - ✅ Never be exposed to browser
 * - ✅ Never be committed to git
 *
 * @throws Error if environment variables are missing or invalid
 * @returns Validated server environment variables
 * @security Server-side only - never expose to browser
 *
 * @module @workspace/supabase-infra/env/server
 */
```

### Client Creation Functions

```typescript
/**
 * Create Supabase admin client with service role
 *
 * ⚠️ **SECURITY WARNING**: This client bypasses RLS and has full database access.
 * **NEVER** use this client in browser code or expose service role key to clients.
 *
 * ## Security Considerations
 *
 * This client uses the **service role key** which:
 * - ✅ Bypasses all Row Level Security policies
 * - ✅ Has full CRUD access to all tables
 * - ✅ Can read/write any user's data
 *
 * @returns Typed Supabase client with service role authentication
 * @security Server-side only - never expose to browser
 * @warning Bypasses Row Level Security
 *
 * @module @workspace/supabase-infra/clients/admin
 */
```

## Formatting Rules

### Line Length

- Max 100 characters per line in JSDoc
- Break long lines at natural word boundaries

### Markdown

Use markdown formatting:

- **Bold** for emphasis: `**text**`
- _Italic_ for definitions: `*text*`
- `Code` for identifiers: `` `text` ``
- Tables for comparisons
- Lists for items

### Code Examples

Always include usage examples:

- Use TypeScript code blocks: ` ```typescript `
- Show realistic variable names
- Include error handling if relevant
- Comment complex parts

### Emojis

Use emojis sparingly for warnings:

- ⚠️ Security warnings
- ✅ Do's
- ❌ Don'ts
- 🚫 Forbidden actions

## AI Agent Instructions

When creating new files:

1. **ALWAYS** add JSDoc header to file
2. **ALWAYS** add JSDoc to exported functions
3. **INCLUDE** usage examples
4. **DOCUMENT** security considerations
5. **EXPLAIN** performance characteristics
6. **LINK** related functions with {@link}

When reviewing code:

1. **CHECK** JSDoc exists
2. **VERIFY** examples are accurate
3. **ENSURE** security warnings present
4. **VALIDATE** @module tag matches path

## Enforcement

- Pre-commit hook checks for JSDoc
- Code review blocks undocumented code
- AI agents auto-generate JSDoc

---

**Last Updated:** 2026-04-04  
**Version:** 1.0.0  
**Compliance:** Mandatory for all exports
