---
name: file-size-check
description: >-
  Enforces file size limits per GR-002. Use when files grow large, refactoring
  giants, or extracting modules.
---

# File Size Check Skill

## Purpose

Enforce file size limits following GR-002 (File Size Limit): max 250 lines per
file.

## When to Trigger

Auto-trigger when user:

- Creates large file (> 200 lines)
- Mentions "file too large" or "extract"
- Commits file > 250 lines

## Skill Instructions

### **1. Size Limits**

| Type                     | Warning   | Error     | Max |
| ------------------------ | --------- | --------- | --- |
| Component                | 200 lines | 250 lines | 250 |
| Server Action            | 80 lines  | 100 lines | 100 |
| Repository               | 150 lines | 200 lines | 200 |
| Edge Function (index.ts) | 40 lines  | 50 lines  | 50  |
| Hook                     | 80 lines  | 100 lines | 100 |

### **2. Extraction Strategy**

```typescript
// ❌ BEFORE - 300 lines
export default function DashboardPage() {
  // ... 300 lines of code
}

// ✅ AFTER - Extracted to components
export default function DashboardPage() {
  return (
    <div>
      <DashboardHeader />      // 80 lines
      <StatsCards />           // 100 lines
      <RecentActivity />       // 120 lines
    </div>
  )
}
```

### **3. Enforce Rules**

- ✅ **GR-002**: Max 250 lines
- ✅ **Extraction**: Identify extractable pieces
- ✅ **SRP**: One file, one responsibility

## Examples

### **User Request**

```
"This file is too large, help me refactor"
```

### **Skill Response**

1. **ANALYZE file:**

   ```
   Current: 350 lines
   Warning: 100 lines over limit
   ```

2. **IDENTIFY extractable:**
   - StatsCards component (100 lines)
   - RecentActivity component (120 lines)
   - Utility functions (80 lines)

3. **EXTRACT to:**
   ```
   app/dashboard/
   ├── page.tsx (50 lines) ✅
   └── _components/
       ├── stats-cards.tsx (100 lines) ✅
       ├── recent-activity.tsx (120 lines) ✅
       └── dashboard-header.tsx (80 lines) ✅
   ```

## Related Skills

- **[single-responsibility](../single-responsibility/)** - SRP enforcement
- **[repository-pattern](../repository-pattern/)** - Extract repositories
- **[edge-function-template](../edge-function-template/)** - Thin index.ts

## References

- **[GR-002: File Size Limit](../../docs/standards/rules/file-size-limit.md)**
- **[GR-008: Single Responsibility](../../docs/standards/rules/single-responsibility.md)**
- **[Component Architecture](../../docs/architecture/components.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
