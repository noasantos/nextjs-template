> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/commit-workflow.mdc`](../../../.cursor/rules/commit-workflow.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# 🔄 Commit Workflow

**This is a CURSOR-SPECIFIC rule file.**

**Full documentation:**
[docs/standards/rules/commit-workflow.md](../../docs/standards/rules/commit-workflow.md)

## Rule for Cursor

Cursor MUST enforce commit workflow:

1. **REMIND** user to run `pnpm workflow`
2. **REMIND** user to run security checks
3. **SUGGEST** conventional commit message
4. **NEVER** commit without workflow check

## Quick Reference

```bash
# 1. Workflow (mandatory)
pnpm workflow              # lint → typecheck → build → format

# 2. Security checks
pnpm check:forbidden
pnpm check:security-smells
pnpm check:docs-drift

# 3. Commit
git add -A
git commit -m "feat(scope): description"
```

## Commit Message Format

```
<type>(<scope>): <description>

Types: feat, fix, docs, test, refactor, chore
```

---

**Rule ID:** COMMIT-WORKFLOW  
**Severity:** REQUIRED  
**Full Docs:**
[docs/standards/rules/commit-workflow.md](../../docs/standards/rules/commit-workflow.md)
