---
name: single-responsibility
description: >-
  Enforces SRP in files and modules per GR-008. Use when refactoring large files
  or splitting responsibilities.
---

# Single Responsibility Skill

## Purpose

Enforce Single Responsibility Principle (SRP) following GR-008.

## When to Trigger

Auto-trigger when user:

- Creates giant file
- Mentions "refactor" or "extract"
- File has multiple responsibilities

## Skill Instructions

### **1. SRP Definition**

**Each file/module/function should have ONE responsibility:**

```typescript
// ✅ CORRECT - One action per file
export async function createTaskAction() {
  /* create only */
}
export async function updateTaskAction() {
  /* update only */
}
export async function deleteTaskAction() {
  /* delete only */
}

// ❌ FORBIDDEN - Multiple responsibilities
export async function taskActions() {
  // create, update, delete all in one
}
```

### **2. Identify Violations**

**Signs of SRP violation:**

- File name contains "And" (e.g., `userAndTaskActions.ts`)
- Function does multiple things
- Module has multiple exports for different concerns
- Comments like "TODO: refactor this"

### **3. Extraction Strategy**

```typescript
// ❌ BEFORE - Multiple responsibilities
export async function manageEverything() {
  // Auth check
  // Validate input
  // Create task
  // Send email
  // Log analytics
}

// ✅ AFTER - Single responsibility each
export async function manageTask() {
  const validated = await validateInput()
  const task = await createTask(validated)
  await sendTaskEmail(task)
  await logAnalytics(task)
}

// Each helper has ONE responsibility
async function validateInput() {
  /* validation only */
}
async function createTask(input) {
  /* creation only */
}
async function sendTaskEmail(task) {
  /* email only */
}
async function logAnalytics(task) {
  /* analytics only */
}
```

### **4. Enforce Rules**

- ✅ **GR-008**: One file, one responsibility
- ✅ **Extraction**: Split multi-responsibility files
- ✅ **Naming**: Name files by responsibility

## Examples

### **User Request**

```
"Refactor this giant function"
```

### **Skill Response**

1. **IDENTIFY responsibilities:**
   - Auth check
   - Validation
   - Business logic
   - Logging
   - Email sending

2. **EXTRACT to separate functions:**

   ```typescript
   async function checkAuth() {
     /* auth only */
   }
   async function validateInput() {
     /* validation only */
   }
   async function processBusiness() {
     /* business only */
   }
   async function logEvent() {
     /* logging only */
   }
   async function sendEmail() {
     /* email only */
   }
   ```

3. **COMPOSE in main function:**
   ```typescript
   export async function main() {
     await checkAuth()
     const validated = await validateInput()
     const result = await processBusiness(validated)
     await logEvent(result)
     await sendEmail(result)
   }
   ```

## Related Skills

- **[file-size-check](../file-size-check/)** - File size limits
- **[repository-pattern](../repository-pattern/)** - One repo per entity
- **[edge-function-template](../edge-function-template/)** - SRP in edge
  functions

## References

- **[GR-008: Single Responsibility](../../docs/standards/rules/single-responsibility.md)**
- **[SRP Guide](../../docs/guides/single-responsibility.md)**
- **[Architecture Principles](../../docs/architecture/principles.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
