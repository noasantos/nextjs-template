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
├── functions/             # Use template
├── tests/                 # pgTAP tests
└── seeds/
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

---

**For AI Agents:** ALWAYS use CLI for migrations. ALWAYS use template for Edge
Functions. ALWAYS test RLS.
