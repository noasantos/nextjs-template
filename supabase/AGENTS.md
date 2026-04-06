# supabase

Supabase configuration: migrations, Edge Functions, database tests.

## 🚨 CRITICAL

**Read before using:**

- [Migration Workflow](../docs/guides/migration-workflow.md)
- [Edge Functions](../docs/architecture/edge-functions.md)

## 📁 Structure

```
supabase/
├── migrations/            # CLI-generated only
├── functions/             # Use template (`pnpm edge:new`)
├── seed.sql               # Post-migration seed data (see [db.seed] in config.toml)
├── tests/                 # pgTAP tests
└── config.toml
```

## 🔒 Golden Rules

**Migrations (GR-015):**

```bash
pnpm supabase:migration:new -- create_users_table
```

**Edge Functions (GR-007):**

```bash
pnpm edge:new -- process-payment
```

## 📖 Full Docs

[Migration Workflow](../docs/guides/migration-workflow.md)  
[Edge Functions](../docs/architecture/edge-functions.md)

## Local stack (`pnpm supabase start`)

1. **Docker Desktop** must be running (`docker info` succeeds).
2. **One stack per default ports:** if another folder’s Supabase uses
   54321/54322, run `supabase stop` there or `supabase stop --all`, then start
   from this repo.
3. **IDE port forwards:** if `supabase start` / `db reset` fails with
   `connection reset by peer` or `EOF` on `127.0.0.1:54321` or `:54322`, check
   `lsof -i :54321 -i :54322`. Cursor (and similar) often binds those ports for
   DB/UI tunnels — disable the forward in the Ports panel (or change
   `[api].port` / `[db].port` in `config.toml` to unused ports).
4. Optional: `supabase start --ignore-health-check` if Kong health checks fail
   but you need containers up; still fix port conflicts for a reliable
   `db reset`.

---

**For AI Agents:** ALWAYS use CLI for migrations. ALWAYS use template for Edge
Functions. ALWAYS test RLS.
