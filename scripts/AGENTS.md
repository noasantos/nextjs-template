# scripts

Automation scripts for development, CI/CD, maintenance.

## 🚨 CRITICAL

**Read before using:**

- [Script Standards](../docs/standards/script-standards.md)
- [Migration Workflow](../docs/guides/migration-workflow.md)
- [Edge Functions](../docs/architecture/edge-functions.md)

## 📁 Categories

**CI/CD:**

- `check:forbidden` - Forbidden patterns (includes no `"use server"` / no
  `apps/*/actions/`; app vs package filename suffixes; see
  `scripts/ci/check-forbidden.mjs`, `docs/standards/package-file-suffixes.md`)
- `check:security-smells` - Security scan
- `check:docs-drift` - Docs sync

**Creation (use templates):**

- `action:new` - Server Actions
- `edge:new` - Edge Functions
- `supabase:migration:new` - Migrations

**QA:**

- `seed:local-users` - Test users

## 🔒 Mandatory Commands

**Always use templates:**

```bash
pnpm action:new -- <module> <name>     # Server Action
pnpm edge:new -- <name>                # Edge Function
pnpm supabase:migration:new -- <name>  # Migration
```

## 📖 Full Docs

[Script Standards](../docs/standards/script-standards.md)  
[Migrations](../docs/guides/migration-workflow.md)  
[Edge Functions](../docs/architecture/edge-functions.md)

---

**For AI Agents:** These scripts enforce consistency. ALWAYS use templates.
NEVER create files manually.
