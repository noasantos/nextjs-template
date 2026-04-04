---
name: doc-template
description: >-
  Provides documentation templates for ADRs and guides per GR-019. Use when
  adding or structuring documentation.
---

# Doc Template Skill

## Purpose

Generate documentation templates following GR-019 and documentation standards.

## When to Trigger

Auto-trigger when user:

- Creates new documentation
- Mentions "doc template" or "documentation structure"
- Starts writing docs

## Skill Instructions

### **1. ADR Template**

```markdown
# ADR-XXX: Title

## Status

[Proposed | Accepted | Deprecated | Superseded]

## Context

What is the issue that we're seeing that is motivating this decision or change?

## Decision

What is the change that we're proposing and/or doing?

## Consequences

What becomes easier or more difficult to do because of this change?

## Alternatives Considered

- Alternative 1: Why it wasn't chosen
- Alternative 2: Why it wasn't chosen

## References

- Link to related docs
- Link to implementation
```

### **2. Business Doc Template**

```markdown
# Domain: [Domain Name]

## Overview

What is this domain about?

## Actors

Who are the actors in this domain?

## Processes

What are the key processes?

## Rules

What are the business rules?

## Events

What events occur in this domain?

## Policies

What policies govern this domain?

## Changelog

- YYYY-MM-DD: Initial version
```

### **3. Guide Template**

```markdown
# Guide: [Guide Name]

## Purpose

Why this guide exists?

## Prerequisites

What do you need before starting?

## Steps

1. Step 1
2. Step 2
3. Step 3

## Examples

Code examples

## Troubleshooting

Common issues and solutions

## References

Related documentation
```

### **4. Enforce Rules**

- ✅ **GR-019**: Three-level structure
- ✅ **Templates**: Use standard templates
- ✅ **Changelog**: Keep updated
- ✅ **Links**: Cross-reference docs

## Examples

### **User Request**

```
"Create an ADR for using Repository Pattern"
```

### **Skill Response**

1. **CREATE file:**

   ```
   docs/architecture/decisions/002-repository-pattern.md
   ```

2. **USE template:**

   ```markdown
   # ADR-002: Repository Pattern

   ## Status

   Accepted

   ## Context

   We need consistent data access patterns...

   ## Decision

   We will use Repository Pattern for all data access...

   ## Consequences

   - Easier testing
   - Better separation of concerns
   - Learning curve for team

   ## Alternatives Considered

   - Direct Supabase calls: Rejected for coupling
   - Active Record: Rejected for testing difficulty

   ## References

   - [Repository Pattern Guide](../guides/repository-pattern.md)
   ```

## Related Skills

- **[three-level-docs](../three-level-docs/)** - Doc levels
- **[jsdoc-generator](../jsdoc-generator/)** - Code docs

## References

- **[GR-019: Three-Level Documentation](../../docs/standards/rules/three-level-docs.md)**
- **[Documentation Guide](../../docs/guides/documentation.md)**
- **[ADR Template](../../docs/templates/adr.md)**

---

**Skill Version:** 1.0.0  
**Last Updated:** 2026-04-04  
**Auto-Update:** Enabled via meta-prompt
