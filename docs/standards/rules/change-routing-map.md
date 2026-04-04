> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/change-routing-map.mdc`](../../../.cursor/rules/change-routing-map.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# Change routing map

- shadcn primitive changes: `packages/ui` via CLI only
- shared product UI: `packages/brand`
- auth/session/proxy helpers: `packages/supabase-auth`
- data access/repositories/actions: `packages/supabase-data`
- Supabase env/typed clients/generated DB types: `packages/supabase-infra`
- schema/RLS/SQL tests: `supabase/`
- template rules/docs/checks: root `docs/`, `AGENTS.md`, `scripts/ci/`
- app-specific presentation: `apps/<app>/app` and local components
