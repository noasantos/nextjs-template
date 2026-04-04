# Turbo Caching

This template treats cache behavior as an explicit contract.

## Current defaults

- `build` restores emitted artifacts from `.next/**` and `dist/**`
- `lint` and `typecheck` are cacheable but do not restore files
- `format` is intentionally **not** cacheable because it mutates the worktree
- DB-backed tasks (`test:integration`, `test:rls`, `test:sql`) are intentionally
  non-cacheable because they depend on local services and database state

## Notes

- Unit-test hashing now tracks both `vitest.config.ts` and `vitest.config.mts`,
  matching the files this repo actually uses.
- Remote caching is optional. If a fork enables it, only deterministic tasks
  with correct outputs should participate.
- Do not mark database reset, migration, or Supabase lifecycle tasks as
  cache-restoring.
