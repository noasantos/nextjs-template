# Client UI: automatic sync and optimistic updates

**Rule:**
[GR-017](../standards/golden-rules.md#gr-017-client-ui-auto-sync-and-optimistic-updates)
in [docs/standards/golden-rules.md](../standards/golden-rules.md).

This document defines expected behaviour when apps call **Server Actions**,
**APIs**, or **hooks** in `@workspace/supabase-data`: the UI must **reflect
server state without `window.location.reload()`** and must not depend on the
user leaving and returning to the page.

## Goals

1. **Automatic sync** — After create, update, or delete, visible lists and
   details must update on their own.
2. **Optimism by default** — For most mutations, assume success in the UI and
   reconcile with the server response (or roll back on error).
3. **Minimal global “loading”** — Avoid full-screen skeleton/spinner; prefer
   local feedback (button `pending`, toast, dimmed row).

## Patterns (in order of preference)

### 1. Cache and invalidation (source of truth)

When **TanStack Query** (or equivalent) exists in `@workspace/supabase-data`:

- After a successful mutation, use **`invalidateQueries`** (or `setQueryData`
  when the response already includes the DTO) for affected keys.
- Do not rely on **manual page refresh** to see new data.

Without React Query yet: after Server Actions, use **`revalidatePath` /
`revalidateTag`** in server handlers (see [Backend](../architecture/backend.md))
and, on the client, **`router.refresh()`** only when Server Components must
re-hydrate — not as a substitute for a domain cache model.

### 2. Optimistic updates

For frequent actions (issue, confirm, archive):

- **`onMutate`**: update cache/local state optimistically (or `setQueryData`).
- **`onError`**: revert to the previous snapshot.
- **`onSettled`**: `invalidateQueries` if reconciliation needs the server.

Avoid blind optimism on **irreversible** or **critical financial** operations
without explicit confirmation; there, button pending + toast may be enough
without changing lists before the response.

### 3. What to avoid

- **`router.refresh()`** in a loop or after every keystroke — expensive and
  opaque.
- **Full-page spinners** for mutations &lt; ~1s when feedback can be on the
  button or row.
- **State only in local memory** without tying invalidation to the domain (data
  becomes wrong after navigation).

### 4. Forms (TanStack Form + Zod)

- Submit calls the mutation; on success: **close modal / reset** + **invalidate
  or inject** the row in the list.
- Server errors: map to the form or toast; **do not** clear optimism without a
  message.

## Checklist for agents / PR review

- [ ] After mutation, does the list or detail update **without** manual reload?
- [ ] Was **optimistic update** considered, or is there a documented reason not
      to use it?
- [ ] Is loading **local** (e.g. button `isPending`) instead of blocking the
      whole app?
- [ ] Does network/API error revert state or show a clear message?

## Links

- [Backend](../architecture/backend.md) — actions, hooks, layer boundaries.
- [AGENTS.md](../AGENTS.md) — entry point and documentation index.
