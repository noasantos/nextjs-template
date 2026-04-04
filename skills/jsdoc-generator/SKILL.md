---
name: jsdoc-generator
description: >-
  Adds JSDoc to exports per GR-021. Use when documenting new files, exports, or
  adding JSDoc.
---

# JSDoc Generator Skill

## Purpose

Generate JSDoc documentation for all exported functions following GR-021 (JSDoc
Required).

## When to Trigger

Auto-trigger when user:

- Creates new file
- Exports function/class
- Mentions "document this" or "add JSDoc"

## Skill Instructions

### **1. File Header**

```typescript
/**
 * [Brief description]
 *
 * [Extended description with key features]
 *
 * @module @workspace/package/path/to-file
 */
```

### **2. Function Documentation**

````typescript
/**
 * [Function name] - [Brief description]
 *
 * [Extended description]
 *
 * ## When to Use
 *
 * **Use this when:**
 * - ✅ [Use case 1]
 *
 * **Do NOT use when:**
 * - ❌ [When not to use]
 *
 * ## Usage
 *
 * ```typescript
 * const result = myFunction(params)
 * ```
 *
 * @param paramName - [Description]
 * @returns [What this returns]
 * @throws [ErrorType] - [When thrown]
 * @security [Security warnings]
 * @performance [Performance notes]
 *
 * @module @workspace/package/path/to-function
 */
export function myFunction(paramName: string): ReturnType {
  // Implementation
}
````

### **3. Enforce Rules**

- ✅ **GR-021**: JSDoc required for all exports
- ✅ **Examples**: Include usage examples
- ✅ **Security**: Document security considerations
- ✅ **Performance**: Document performance characteristics

## Examples

### **User Request**

```
"Add documentation to this function"
```

### **Skill Response**

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
 * const claims = await getClaims()
 * if (!claims?.sub) throw new Error("Unauthorized")
 * ```
 *
 * @returns JWT claims object or null if not authenticated
 * @security Preferred over getUser() for simple auth checks
 * @performance Cached with React.cache() - deduplicated per request
 *
 * @module @workspace/supabase-auth/session/get-claims
 */
export const getClaims = cache(async (): Promise<JWTClaims | null> => {
  // Implementation
})
````

## Related Skills

- **[server-action-template](../server-action-template/)** - Document actions
- **[repository-pattern](../repository-pattern/)** - Document repositories
- **[edge-function-template](../edge-function-template/)** - Document edge
  functions

## References

- **[GR-021: JSDoc Required](../../docs/standards/rules/jsdoc-required.md)**
- **[JSDoc Style Guide](../../docs/standards/jsdoc-style-guide.md)**
- **[Documentation Standards](../../docs/standards/documentation.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
