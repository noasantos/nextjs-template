# Data access pattern: Server Actions + TanStack Query hooks

This document is the **canonical contract** for how presentation code reaches
the database in this template: **Server Actions** for the server boundary,
**TanStack Query hooks** for client-side caching, loading state, and
invalidation.

**Related:** [Client UI data sync](../guides/client-ui-data-sync.md) ·
[Backend](./backend.md) ·
[Repository standards](../standards/repository-standards.md)

---

## Rationale

Two layers are intentional:

1. **Security and secrets** — Server Actions run on the server with access to
   cookies, `requireAuth()`, and `createServerAuthClient()`. The browser never
   receives service credentials or raw repository constructors for ad-hoc SQL.

2. **Reactivity and UX** — Client components need stable loading/error state,
   deduplication, and post-mutation cache updates. TanStack Query provides that;
   calling a Server Action **directly** from event handlers bypasses a single
   place to invalidate or optimistically update the cache.

Hooks are the **application-layer adapter** between UI and actions, not a
duplicate domain model.

---

## Where code lives

| Artifact             | Package                    | Path (canonical)                                                                          |
| -------------------- | -------------------------- | ----------------------------------------------------------------------------------------- |
| Server Action        | `@workspace/supabase-data` | `src/actions/<domain>/<action-name>.codegen.ts`                                           |
| Client hook          | `@workspace/supabase-data` | `src/hooks/<domain>/use-<entity>-query.hook.codegen.ts` or `...-mutation.hook.codegen.ts` |
| Query key factory    | `@workspace/supabase-data` | `src/hooks/<domain>/query-keys.codegen.ts`                                                |
| Repository (codegen) | `@workspace/supabase-data` | `src/modules/<domain>/infrastructure/...`                                                 |

- **Scaffold (human or LLM):** `pnpm action:new -- <module> <action-name>`
- **Scaffold hooks:** `pnpm hook:new -- <domain> <entity> <query|mutation>`

Future **codegen** may emit actions and hooks into these same paths by reusing
the scaffolds as templates.

---

## Decision table: hook vs direct action call

| Situation                                                     | Use                                                                                     |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Client Component needs data with cache, refetch, `isPending`  | **`useQuery` hook** that calls the action inside `queryFn`                              |
| Client Component mutates data and must refresh lists/details  | **`useMutation` hook**; `invalidateQueries` / `setQueryData` on success                 |
| Server Component or Route Handler                             | **Call the action or repository** directly (no TanStack on server)                      |
| `<form action={serverAction}>` (Next.js / React form actions) | **Form `action` prop** — allowed without a hook wrapper                                 |
| `useActionState(action, initial)`                             | **Allowed** — pass the **action function reference** (not `action()` in random effects) |
| One-off imperative call in client without cache concerns      | **Avoid**; if unavoidable, document and prefer hook; see Rule 4                         |

---

## Observability (logging), not only errors

Actions must emit **structured lifecycle logs** for operations analysis, not
only when something throws.

- Use **`logServerEvent`** from `@workspace/logging/server` on the **server**
  (inside Server Actions and route handlers).
- Log **success and failure** paths with consistent `component`, `eventFamily`,
  `eventName`, `outcome`, `durationMs`, and **rich `metadata`** (entity ids,
  correlation ids, safe input summaries — no secrets, no PII dumps).
- Treat logging as **observability**: dashboards, SLOs, and support workflows,
  not as a substitute for returning typed errors to the client.

Hooks **must not** use `console.log`; client-side analytics or error reporting
should follow app-level patterns (e.g. product observability packages), not raw
console.

---

## Query key factory (required)

Each domain folder under `hooks/<domain>/` owns a **`query-keys.codegen.ts`**
file that exports a **typed factory** (e.g. `catalogQueryKeys`). Hooks import
keys from this module only — **no string literals** scattered across components.

Example shape:

```typescript
// packages/supabase-data/src/hooks/catalog/query-keys.codegen.ts
export const catalogQueryKeys = {
  all: ["catalog"] as const,
  referenceValues: () => [...catalogQueryKeys.all, "reference-values"] as const,
  referenceValuesList: (filters?: { scope?: string }) =>
    [...catalogQueryKeys.referenceValues(), "list", filters ?? {}] as const,
}
```

---

## Example: action → `useQuery` → component

**Server Action** (excerpt — full file from `pnpm action:new`):

```typescript
"use server"

import { listReferenceValuesAction } from "@workspace/supabase-data/actions/catalog/list-reference-values.codegen"
// implementation: auth, logServerEvent, repository, serializeResult
```

**Hook:**

```typescript
"use client"

import { useQuery } from "@tanstack/react-query"

import { listReferenceValuesAction } from "@workspace/supabase-data/actions/catalog/list-reference-values.codegen"
import { catalogQueryKeys } from "@workspace/supabase-data/hooks/catalog/query-keys.codegen"

export function useReferenceValuesListQuery(filters?: { scope?: string }) {
  return useQuery({
    queryKey: catalogQueryKeys.referenceValuesList(filters),
    queryFn: () => listReferenceValuesAction({ scope: filters?.scope }),
  })
}
```

**Component:**

```typescript
"use client"

import { useReferenceValuesListQuery } from "@workspace/supabase-data/hooks/catalog/use-reference-values-query.hook.codegen"

export function ReferenceValuesPanel() {
  const { data, isPending, error } = useReferenceValuesListQuery()
  if (isPending) return <span>Loading…</span>
  if (error) return <span>Failed to load</span>
  return <ul>{/* render data */}</ul>
}
```

---

## Example: action → `useMutation` → `invalidateQueries`

```typescript
"use client"

import { useMutation, useQueryClient } from "@tanstack/react-query"

import { createReferenceValueAction } from "@workspace/supabase-data/actions/catalog/create-reference-value.codegen"
import { catalogQueryKeys } from "@workspace/supabase-data/hooks/catalog/query-keys.codegen"

export function useCreateReferenceValueMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (input: { code: string; label: string }) =>
      createReferenceValueAction(input),
    onSettled: async () => {
      await queryClient.invalidateQueries({
        queryKey: catalogQueryKeys.referenceValues(),
      })
    },
  })
}
```

Prefer **`setQueryData`** when the mutation response includes the full row and
you can update the list without a round trip.

---

## Rule 4 — code smell (direct action calls in client components)

**Smell:** In a file marked **`"use client"`**, calling an imported Server
Action like `await myAction()` from `onClick`, `useEffect`, or arbitrary
handlers **without** going through:

- `useQuery` / `useMutation` **`queryFn` / `mutationFn`**, or
- a **form** `action={...}` prop, or
- **`useActionState(fn, ...)`** with the server action as **`fn`** (reference,
  not `fn()` in random effects)

**Why it matters:** cache and invalidation drift; duplicate request patterns;
hard to enforce optimistic updates and GR-017.

**Remediation:** wrap the call in a hook, or move the fetch to a Server
Component / route.

**Enforcement:** This template **does not** add a second linter. **Oxlint** is
the only configured linter (`pnpm lint`). Rule 4 is enforced by **code review**,
checklists in [client UI data sync](../guides/client-ui-data-sync.md), and
optional **integration tests** or a **future** Oxlint plugin / small `node`
script under `scripts/ci/` if the maintainers want automation — **not** ESLint
(see [Oxlint / Oxfmt](../tools/oxlint-oxfmt.md)).

---

## Future: codegen + semantic layer

Repository codegen is **deterministic**. Actions and hooks may require a
**non-deterministic (LLM) pass** for:

- which mutations need optimistic updates,
- which query keys to invalidate together,
- input/output Zod shapes tied to product rules.

The intended workflow is: **scaffold** with `action:new` / `hook:new`, then
**codegen or agent** fills implementations while preserving paths, logging, and
this document's rules.

---

## See also

- [Client UI: automatic sync and optimistic updates](../guides/client-ui-data-sync.md)
- [LLM-to-LLM prompt: action + hook codegen](../guides/llm-prompt-action-hook-codegen.md)
- [Backend standards](./backend.md)
- [Backend codegen](../guides/backend-codegen.md)
- [Logging (structured, no console)](../../.cursor/skills/logging-required/SKILL.md)
