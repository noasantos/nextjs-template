# Repository scripts

Small automation used by root `package.json` and local workflows. Prefer
`pnpm <script>` over calling these paths directly unless noted.

| Directory                  | Role                                                                                                                                      |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| [`ci/`](./ci/)             | Repo guards (`check-forbidden.mjs`, `check-security-smells.mjs` — BAD-003, GR-013, admin client boundaries, `packages/ui` diff / GR-001). |
| [`dev/`](./dev/)           | Local developer checks (`env-check-local.mjs` — optional manual run).                                                                     |
| [`test/`](./test/)         | Test pipeline helpers (`integration-test-then-reset-db.mjs`).                                                                             |
| [`supabase/`](./supabase/) | Migration wrappers (`migration-new.sh`, `migration-stamp.sh`, `guard.sh`).                                                                |

`migration-new.sh` runs `supabase migration new` **without** `$(...)` around it
so the CLI is not stuck on a pipe (stdout may never close when captured).
**Stdin** is `/dev/null` (no interactive block in CI/agents). **Supabase
stdout** is discarded so output is not duplicated; **stderr** is still shown if
the CLI errors.

**Success output:** a **single line** to stdout — the repo-relative path to the
new `.sql` file (for humans and for LLMs to pass to
`pnpm supabase db diff -o …`). `pnpm` may still print its own task header above
that line.

This does **not** make the command “instant” in zero time: duration is however
long the Supabase process takes until it **exits** (usually well under a second
locally). What is avoided is **indefinite** hangs from pipe EOF or stdin.

## Commands (from repo root)

| Script                                       | Invoked by                                                                                                                 |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `pnpm check:forbidden`                       | `node scripts/ci/check-forbidden.mjs` (optional `ALLOW_PACKAGES_UI_CHANGES=1` for shadcn PRs)                              |
| `pnpm check:security-smells`                 | `node scripts/ci/check-security-smells.mjs` — unsafe `NEXT_PUBLIC_*` names, service role in client, `.env.example` hygiene |
| `pnpm audit:dependencies`                    | `pnpm audit --audit-level=high` (also run in CI with `continue-on-error` until advisories are resolved)                    |
| `pnpm check:docs-drift`                      | `node scripts/ci/check-docs-drift.mjs`                                                                                     |
| `pnpm bundle:analyze:example`                | `pnpm --filter example analyze:bundle` + `node scripts/ci/analyze-next-bundle.mjs .next`                                   |
| `pnpm test:integration:reset-local-db-after` | `node scripts/test/integration-test-then-reset-db.mjs`                                                                     |
| `pnpm supabase:migration:new`                | `bash scripts/supabase/migration-new.sh`                                                                                   |
| `pnpm supabase:migration:stamp`              | `bash scripts/supabase/migration-stamp.sh`                                                                                 |
| `pnpm env:check:local`                       | `node scripts/dev/env-check-local.mjs` — validates `.env.local` for local builds                                           |
