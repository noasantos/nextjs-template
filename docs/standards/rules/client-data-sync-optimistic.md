> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/client-data-sync-optimistic.mdc`](../../../.cursor/rules/client-data-sync-optimistic.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# Client data sync and optimistic UI

When implementing or integrating **Server Actions**, **API calls**, or
**`@workspace/supabase-data` hooks** in app UI:

## Required mindset

1. **No manual refresh** — After create/update/delete, visible lists and detail
   views must update **without** full page reload or asking the user to refresh.
   Use **cache invalidation**, **`setQueryData`**, **`revalidatePath` /
   `revalidateTag`**, or targeted **`router.refresh()`** only when Server
   Components must re-fetch (not as default for every action).

2. **Prefer optimistic behavior** — For most mutations, update the UI
   optimistically (or immediately reflect success), then reconcile with the
   server response; **rollback** on error. Defer optimism only for irreversible
   or high-risk operations (document why).

3. **Minimize global loading** — Avoid full-page spinners/skeletons for quick
   mutations; use **button `pending`**, row-level state, or subtle indicators.
   Reserve full-page loading for true initial data dependencies.

## Implementation hints

- After successful mutation: **invalidate the right query keys** or **patch
  cache** with returned DTOs.
- Forms: on success, **reset/close** and **sync list/detail** via invalidation
  or optimistic insert — see `docs/guides/client-ui-data-sync.md`.
- Do not rely on **`window.location.reload()`** for normal flows.
