## Summary

- [ ] This change stays within the template’s package and layering rules.
- [ ] Docs were updated for any behavior, workflow, or contract change.
- [ ] No forbidden patterns were introduced (`packages/ui` edits, manual
      migrations, app-local DB layers, server `getSession()`, barrel
      re-exports).
- [ ] I checked whether auth, data, schema, or public contracts changed.
- [ ] I checked whether this alters guarantees for downstream forks.

## Verification

- [ ] `pnpm workflow`
- [ ] `pnpm check:forbidden`
- [ ] `pnpm check:security-smells`
- [ ] `pnpm check:docs-drift`
- [ ] `pnpm test:coverage`
- [ ] `pnpm test:db` (pgTAP) and/or `pnpm test:rls` / `pnpm test:sql` if
      schema/RLS/auth-sensitive persistence changed
