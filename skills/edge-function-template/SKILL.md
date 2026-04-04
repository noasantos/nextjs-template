---
name: edge-function-template
description: >-
  Creates Supabase Edge Functions with SRP and logging per GR-007 and GR-008.
  Use when creating edge functions or running pnpm edge:new.
---

# Edge Function Template Skill

## Purpose

Create Edge Functions with proper structure, logging, and Single Responsibility
Principle following GR-007 and GR-008.

## When to Trigger

Auto-trigger when user:

- Asks to "create Edge Function"
- Mentions "supabase function" or "edge"
- Wants serverless logic

## Skill Instructions

### **1. Use Template Command**

```bash
pnpm edge:new -- <function-name>
```

This creates:

```
supabase/functions/{name}/
├── index.ts          # HTTP layer (< 50 lines)
├── handler.ts        # Business logic
├── types.ts          # Type definitions
├── validation.ts     # Input validation
└── _shared/
    ├── cors.ts       # Shared CORS
    └── supabase.ts   # Shared client
```

### **2. Follow SRP**

```typescript
// index.ts - HTTP layer ONLY
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { handleMyFunction } from "./handler.ts"

serve(async (req) => {
  // CORS, parse, delegate to handler
})

// handler.ts - Business logic ONLY
export async function handleMyFunction(request, req) {
  // Business logic here
}
```

### **3. Enforce Rules**

- ✅ **GR-007**: Use template command
- ✅ **GR-008**: SRP (one file, one responsibility)
- ✅ **Logging**: Use logEdgeEvent
- ✅ **Size**: index.ts < 50 lines

## Examples

### **User Request**

```
"Create an Edge Function for processing payments"
```

### **Skill Response**

1. **RUN template:**

   ```bash
   pnpm edge:new -- process-payment
   ```

2. **GUIDE implementation:**
   - Define types in types.ts
   - Implement validation in validation.ts
   - Add business logic in handler.ts
   - Keep index.ts thin

3. **REMIND rules:**
   - "Keep index.ts under 50 lines (GR-008)"
   - "Use logEdgeEvent for logging"
   - "Use \_shared/ utilities"

## Related Skills

- **[logging-required](../logging-required/)** - Edge logging
- **[single-responsibility](../single-responsibility/)** - SRP enforcement
- **[security-check](../security-check/)** - Security scan

## References

- **[GR-007: Edge Function Template](../../docs/standards/rules/edge-function-template.md)**
- **[GR-008: Single Responsibility](../../docs/standards/rules/single-responsibility.md)**
- **[Edge Functions Architecture](../../docs/architecture/edge-functions.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
