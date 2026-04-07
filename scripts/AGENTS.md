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

**Backend codegen:**

- **Do not hand-edit** `*.codegen.*`; fix `scripts/codegen/*` and
  `packages/codegen-tools/` and re-run. `pnpm codegen:clean` deletes only
  `*.codegen.*` (plus semantic plan placeholder); `profiles` / `user-access` /
  `user-roles` modules and `codegen:backend` `*.ts` stubs are **not** matched.
- `codegen:domain-map:validate` - Validate `config/domain-map.json` vs
  `database.types.ts`
- `codegen:domain-map:sync` - Report tables missing from map / stale map rows
- `codegen:snapshot-types` - Copy canonical types into
  `packages/codegen-tools/workspace/` (gitignored) for optional `--types`
- `codegen:sandbox` - Write throwaway stubs under
  `packages/supabase-data/src/modules/codegen-sandbox/` (real table
  `observability_events`)
- `codegen:sandbox:clean` - Delete that module + runtime sandbox map file
- `codegen:backend` - Stub repositories (`--check` default, `--write` to emit)
- See [Backend codegen](../docs/guides/backend-codegen.md)

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
