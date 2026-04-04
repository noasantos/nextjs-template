# 🛠️ AI Agent Skills

Custom skills for all AI agents working with this codebase.

## 📚 Available Skills

### **Architecture & Patterns**

1. **[server-action-template](./server-action-template/)** - Create Server
   Actions with logging
2. **[repository-pattern](./repository-pattern/)** - Implement repository
   pattern correctly
3. **[edge-function-template](./edge-function-template/)** - Create Edge
   Functions with SRP

### **Security & Auth**

4. **[logging-required](./logging-required/)** - Enforce structured logging
   (GR-005)
5. **[auth-invariants](./auth-invariants/)** - Enforce auth patterns (getClaims
   vs getUser)
6. **[security-check](./security-check/)** - Scan for security issues

### **Code Quality**

7. **[jsdoc-generator](./jsdoc-generator/)** - Generate JSDoc for exports
8. **[file-size-check](./file-size-check/)** - Check file size limits
9. **[single-responsibility](./single-responsibility/)** - Enforce SRP

### **Database**

10. **[migration-workflow](./migration-workflow/)** - Guide through migration
    creation
11. **[rls-test-generator](./rls-test-generator/)** - Generate RLS tests per
    table

### **Testing**

12. **[test-location-guide](./test-location-guide/)** - Guide to correct test
    location (GR-010)
13. **[test-generator](./test-generator/)** - Generate tests in correct location
14. **[tdd-workflow](./tdd-workflow/)** - Enforce TDD workflow

### **Documentation**

15. **[three-level-docs](./three-level-docs/)** - Guide to correct doc level
    (GR-019)
16. **[doc-template](./doc-template/)** - Generate documentation templates

### **Prompting**

17. **[llm-to-llm-prompt](./llm-to-llm-prompt/)** - Machine prompts for
    downstream LLMs (English, execution-focused)

### **Template Hardening Tools**

18. **[Package file suffixes](../docs/standards/package-file-suffixes.md)** —
    `*.component.tsx` / `*.hook.*` / `*.provider.tsx` in `brand` / `core` /
    `forms` / `seo` (not `apps/`, not `packages/ui`); `pnpm check:forbidden`
19. **[dependency-cruiser](../docs/tools/dependency-cruiser.md)** - Enforce
    architectural boundaries
20. **[Knip](../docs/tools/knip.md)** - Detect unused dependencies, exports, and
    files
21. **[next-safe-action](../docs/tools/next-safe-action.md)** - Type-safe Server
    Actions with auth middleware
22. **[TypeScript Strict Flags](../docs/tools/typescript-strict.md)** - Enforce
    strict type checking
23. **[Security Scanners](../docs/tools/security-scanners.md)** - Automated
    security scanning (OSV, actionlint, zizmor)
24. **[publint](../docs/tools/publint.md)** - Package linting for published
    packages

## 🤖 How to Use

### **Auto-Trigger**

Skills auto-trigger based on context:

```
User: "Create a Server Action for creating tasks"
→ Triggers: server-action-template skill
```

### **Manual Trigger**

User can explicitly request:

```
User: "Use the test-location-guide skill"
→ AI agent follows skill instructions
```

### **AI Agent Decision**

AI agents should:

1. **IDENTIFY** which skill matches the task
2. **TRIGGER** the skill automatically
3. **FOLLOW** skill instructions precisely
4. **REMIND** user about skill usage

## 🔄 Skill Updates

Skills are auto-updated via meta-prompt:

```bash
# Run monthly or when docs change
pnpm skills:update
```

This ensures skills stay synchronized with:

- Golden Rules in `docs/standards/rules/`
- Architecture docs in `docs/architecture/`
- Best practices in `docs/guides/`

## 📊 Skill Coverage

| Category           | Skills | Coverage           |
| ------------------ | ------ | ------------------ |
| Architecture       | 3      | 100% of patterns   |
| Security & Auth    | 3      | 100% of invariants |
| Code Quality       | 3      | 100% of rules      |
| Database           | 2      | 100% of workflows  |
| Testing            | 3      | 100% of strategies |
| Documentation      | 2      | 100% of levels     |
| Prompting          | 1      | LLM-to-LLM prompts |
| Template Hardening | 6      | 100% of tooling    |
| **Total**          | **23** | **100% coverage**  |

## 🎯 For Different AI Agents

### **Cursor IDE**

- Discovers **Agent Skills** from `.cursor/skills/<skill-name>/SKILL.md`
  (symlink to `skills/<skill-name>/SKILL.md`).
- Each `SKILL.md` includes YAML frontmatter with `name` and `description` for
  discovery.
- Invoke with `/skill-name` or attach the skill in Agent chat; see
  [Cursor Skills docs](https://www.cursor.com/docs/context/skills).

### **Claude (CLI/API)**

- Reads from `skills/*/SKILL.md`
- Reference in prompts
- Same content as Cursor

### **GitHub Copilot / Codex**

- Reads from `skills/*/SKILL.md`
- Reference in comments
- Standard markdown

### **Gemini**

- Reads from `skills/*/SKILL.md`
- Same as Claude
- Standard markdown

## 📝 Skill Structure

Each `SKILL.md` starts with frontmatter, then body:

```markdown
---
name: skill-name
description: What it does and when to use it (third person, trigger terms).
---

# Skill Name

## Purpose

- When to trigger (auto/manual)
- What it does

## Skill Instructions

- Step-by-step guide
- Code examples
- Rules to enforce

## Examples

- User request
- Skill response
- Implementation guide

## Related Skills

- Cross-references

## References

- Links to Golden Rules
- Links to architecture docs
```

---

**For AI Agents:** Always use skills when available. They encode institutional
knowledge and ensure consistency across all AI agents.

**Last Updated:** 2026-04-04  
**Version:** 1.0.0  
**Compatibility:** Cursor, Claude, GitHub Copilot, Gemini
