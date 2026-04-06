---
name: backend-domain-map
description: >-
  Infer and review domain-map.json from Supabase database.types.ts: group tables
  into kebab-case domains using FKs and naming heuristics, self-review once,
  then output JSON for codegen:domain-map:validate. Use as a subagent from
  backend-domain-codegen-init.
---

# Backend domain map (infer + review)

## Purpose

Produce or merge [`config/domain-map.json`](../../config/domain-map.json) so
every `Database["public"]["Tables"]` key is either assigned to exactly one
domain or listed in `ignoreTables`. **Always persist the map at that path** (not
under `packages/codegen-tools/fixtures/` or `workspace/`). Types input is
usually the canonical `database.types.ts` or an optional snapshot from
`pnpm codegen:snapshot-types` (see
[`packages/codegen-tools/workspace/README.md`](../../packages/codegen-tools/workspace/README.md)).

## When to trigger

- User or parent skill asks to **map schema tables to domains** before codegen.
- After `pnpm codegen:domain-map:sync` shows new tables.

## Instructions

1. **Read-only types:** Do not edit
   [`packages/supabase-infra/src/types/database.types.ts`](../../packages/supabase-infra/src/types/database.types.ts)
   (regenerate with `pnpm supabase:types:local` or
   `pnpm supabase:types:linked`).

2. **Extract table names** from `public.Tables` (and note FK `Relationships` to
   keep related tables in the same domain when it matches product language).

3. **Heuristics** (apply judgment, prefer cohesion over many tiny domains):
   - Shared prefix (`calendar_*`, `stripe_*`, `psychologist_*`) → one domain per
     product area when it stays maintainable.
   - Audit / log / webhook / idempotency tables → domain `platform-audit` or
     `ignoreTables` if not exposed via `@workspace/supabase-data`.
   - Reference/lookup tables → same domain as primary consumers or a small
     `reference-data` domain.

4. **Domain id:** kebab-case only (`user-roles`, not `user_roles`).

5. **Flags per domain** (schema v1):
   - `codegen: false` for tables already hand-maintained or infra-only.
   - `readOnly`, `exposeActions`, `auth`: `public` | `session` | `admin`.

6. **Self-review (mandatory):** After the first draft, fix: duplicate table
   assignments, orphan tables, domains that bundle unrelated aggregates. Refine
   **once** before handing off.

7. **Repository plan (downstream):** `domain-map.json` is structural only. For
   per-table **methods / DTOs / view-backed reads**, the coding agent uses
   `pnpm codegen:repository-plan:context` plus
   `packages/codegen-tools/prompts/repository-plan/v1.md` to author
   `config/repository-plan.json`, then `pnpm codegen:repository-plan:validate`
   and `pnpm codegen:backend --plan ...` (see
   [`docs/guides/backend-codegen.md`](../../docs/guides/backend-codegen.md)).

8. **Validate:** The orchestrator must run:

   ```bash
   pnpm codegen:domain-map:validate
   ```

## Output

- Valid JSON matching version `1` (see
  [`packages/codegen-tools/src/domain-map-schema.ts`](../../packages/codegen-tools/src/domain-map-schema.ts)).
- Short note listing ambiguous tables and why you placed them.

## References

- [docs/guides/backend-codegen.md](../../docs/guides/backend-codegen.md)
- [docs/architecture/backend.md](../../docs/architecture/backend.md)
