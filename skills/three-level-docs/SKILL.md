---
name: three-level-docs
description: >-
  Places docs at the correct level (root, apps/docs, app) per GR-019. Use when
  writing documentation or deciding doc location.
---

# Three-Level Docs Skill

## Purpose

Guide to correct documentation level following GR-019 (Three-Level
Documentation).

## When to Trigger

Auto-trigger when user:

- Creates documentation
- Mentions "docs" or "documentation"
- Unsure where to put docs

## Skill Instructions

### **1. Level Decision Tree**

```
Is it template-wide standards?
└─ YES → Level 1: docs/

Is it product/business documentation?
└─ YES → Level 2: apps/docs/

Is it app-specific documentation?
└─ YES → Level 3: apps/<app>/docs/
```

### **2. Level 1 - Template Standards**

**Location:** `docs/`

**Content:**

- Golden Rules
- ADRs (Architecture Decision Records)
- Architecture overview
- Coding standards
- Testing strategy

**Examples:**

```
docs/
├── standards/golden-rules.md
├── architecture/overview.md
├── guides/testing.md
└── reference/stack.md
```

### **3. Level 2 - Cross-App Business**

**Location:** `apps/docs/`

**Content:**

- Product overview
- Domain models
- Business rules
- Trust & safety policies
- Operations guides

**Examples:**

```
apps/docs/
├── overview/product-overview.md
├── trust-safety/solver-onboarding.md
├── policy/dispute-policy.md
└── operations/admin-operations.md
```

### **4. Level 3 - Single-App Domain**

**Location:** `apps/<app>/docs/`

**Content:**

- App-specific features
- SEO documentation
- App-specific guides
- Component documentation

**Examples:**

```
apps/web/docs/
├── seo.md
├── features/dashboard.md
└── components/README.md
```

### **5. Enforce Rules**

- ✅ **GR-019**: Three-level structure
- ✅ **No duplication**: Each doc in one level
- ✅ **Clear scope**: Know your audience

## Examples

### **User Request**

```
"Where should I document this feature?"
```

### **Skill Response**

1. **IDENTIFY scope:**
   - Template-wide? → Level 1 (docs/)
   - Product/business? → Level 2 (apps/docs/)
   - App-specific? → Level 3 (apps/web/docs/)

2. **GUIDE to location:**

   ```
   For authentication flow:
   - Architecture → docs/architecture/auth.md (Level 1)
   - Business rules → apps/docs/auth/business-rules.md (Level 2)
   - Implementation → apps/web/docs/auth/implementation.md (Level 3)
   ```

3. **REMIND rules:**
   - "Don't duplicate across levels"
   - "Link between levels when needed"

## Related Skills

- **[doc-template](../doc-template/)** - Generate doc templates
- **[jsdoc-generator](../jsdoc-generator/)** - Code documentation

## References

- **[GR-019: Three-Level Documentation](../../docs/standards/rules/three-level-docs.md)**
- **[Documentation Guide](../../docs/guides/documentation.md)**
- **[Architecture Docs](../../docs/architecture/)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
