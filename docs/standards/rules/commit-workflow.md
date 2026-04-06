> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/commit-workflow.mdc`](../../../.cursor/rules/commit-workflow.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# Commit workflow

**Docs mirror:** `docs/standards/rules/commit-workflow.md` — run
`pnpm sync:cursor-rules-docs` after editing this file.

## Rule for Cursor / LLM agents

### When the user asks to commit

1. **Commit only what is staged.** Do not run `git add -A` or stage unrelated
   working-tree changes unless the user asked to include them. Use `git status`
   / `git diff --cached` to confirm.
2. **Do not run the full local CI pipeline manually before `git commit`**
   (`pnpm workflow`, `pnpm test`, `pnpm typecheck`, etc.) as a substitute for
   committing. **Lefthook runs on `git commit`:**
   - **pre-commit:** `pnpm format`, `oxlint`, changelog check,
     security/forbidden/docs-drift/cursor-rules parity, etc. (see
     `lefthook.yml`).
   - **commit-msg:** `commitlint` (conventional commits).
3. If **pre-commit fails**, fix the reported issues (or only then run the
   specific failing command), then commit again.
4. **Pre-push** (runs on `git push`, not on commit): `pnpm typecheck`,
   `pnpm test`, publint, knip, etc. Agents should not run the full pre-push
   suite before every commit unless the user explicitly wants a dry run before
   pushing.
5. **Suggest** a conventional commit message (`type(scope): description` per
   `commitlint.config.js`). Types include `feat`, `fix`, `docs`, `refactor`,
   `chore`, `ci`, `build`, `perf`, `test`, `style`, `revert`.

### Optional (human / explicit request)

- Before a large PR, running `pnpm workflow` or targeted checks is fine; it is
  **not** required before every commit when hooks are installed.

## Commit message format

```
<type>(<scope>): <description>
```

**Rule ID:** COMMIT-WORKFLOW
