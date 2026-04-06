# Changelog

## [Unreleased]

### Added

- [feat] `config/domain-map.example.json` +
  `config/repository-plan.example.json` (generic `demo_*` tables vs
  `database.types.mock.ts`), `config/README.md`, `pnpm codegen:*:example`
  scripts, and `.gitignore` entries for local `config/domain-map.json` /
  `config/repository-plan.json`; CI runs example-based codegen checks.
- [feat] `.cursor/skills/<name>/SKILL.md` symlinks for every `skills/*/SKILL.md`
  (Cursor discovery); `pnpm skills:sync-cursor` +
  `scripts/skills/sync-cursor-skills.sh` to regenerate after new skills;
  `scripts/skills/validate-skills.ts` for `pnpm skills:validate` (frontmatter
  `name` vs folder + symlink check).
- [feat] Skill `repository-plan-autonomous-pipeline` — human-free sequence:
  validate domain-map → `codegen:repository-plan:context` → agent writes full
  `repository-plan.json` → strict validate →
  `codegen:backend --plan --write --force`.
- [feat] `pnpm codegen:repository-plan:context` — deterministic JSON for the
  coding agent to author `config/repository-plan.json` (no OpenAI CLI in repo).
- [feat] Backend stubs: `codegen: true` on every `config/domain-map.json` domain
  except hand-maintained `profiles` and `user-roles`;
  `pnpm codegen:backend --write` emits repository + port stubs under
  `packages/supabase-data/src/modules/**`; `@workspace/supabase-data` `exports`
  expanded (sorted) including `./lib/supabase-repository-error`.
- [feat] `pnpm codegen:sandbox` / `pnpm codegen:sandbox:clean` — generate
  throwaway stubs under `modules/codegen-sandbox/` from real types
  (`observability_events`) without editing `config/domain-map.json`; doc in
  `docs/guides/backend-codegen.md`.

### Changed

- [docs] `config/README.md`: clarify template (ignored local maps) vs fork
  (optional commit); restore `.gitignore` entries for `config/domain-map.json`
  and `config/repository-plan.json` so template PRs ship only `*.example.json`.
- [refactor] Codegen CLIs (`domain-map:validate`, `repository-plan:validate`,
  `repository-plan:context`, `domain-map:sync`, `codegen:backend`) resolve
  `config/domain-map.json` / `config/repository-plan.json` when present, else
  the matching `*.example.json` (`scripts/codegen/config-defaults.ts`). The
  committed template remains the example files; local copies override when you
  create them.
- [refactor] Codegen integration scaffolds: emit under
  `tests/integration/supabase-data/modules/<domain>/` (mirrors
  `packages/supabase-data/src/modules/<domain>/`) instead of a flat
  `tests/integration/supabase-data/codegen/` folder; see `integrationTestPath`
  in `@workspace/codegen-tools`.
- [refactor] Regenerate `config/repository-plan.json` for all codegen-enabled
  domain tables (65 entries), with strict `idColumn` where the Row has no `id`
  (`google_sync_idempotency`, `sync_locks`, `webhook_events`, etc.), `upsert` on
  `google_sync_idempotency` (`idempotency_key`), and `psychologist_assistants`
  limited to `list` + `insert` (composite PK; codegen targets a single surrogate
  column). Re-run
  `pnpm codegen:backend --write --plan config/repository-plan.json --mode strict --force`
  for matching DTOs, mappers, ports, repositories, and integration test
  scaffolds.
- [refactor] Repository plan: remove `codegen:repository-plan:infer` (OpenAI);
  semantic step is always the coding agent with
  `codegen:repository-plan:context` + `prompts/repository-plan/v1.md`. Rename
  export to `@workspace/codegen-tools/build-repository-plan-context`.
- [docs] `supabase/AGENTS.md` and `supabase/config.toml`: troubleshoot local
  `supabase start` / `db reset` (Docker, `stop --all`, IDE port conflicts on
  54321/54322, optional `--ignore-health-check`).
- [refactor] Supabase seeds: consolidate all post-migration SQL into a single
  `supabase/seed.sql` (sections commented: bootstrap, buckets, reference values,
  clinical activities, document templates, subscription plans). `config.toml`
  `[db.seed].sql_paths` is `["./seed.sql"]`; remove `supabase/seeds/` directory.
  Docs: `supabase-setup`, `migration-workflow`, `supabase/AGENTS.md`.
- [docs] Skill `backend-domain-codegen-init`: document mock + workspace map
  experiment flow (validate / `codegen:backend --check` with fixture types).
- [docs] `backend-codegen.md`: explain `codegen: false` default and `--check` vs
  `--write`.

### Fixed

- [fix] `config/domain-map.json`: assign every `public` table to a bounded
  domain (catalog, calendar, clinical, billing, sync, marketplace, audit, etc.)
  with `ignoreTables: []`; drop stale `profiles` / `app_roles` /
  `observability_events` references so `pnpm codegen:domain-map:validate`
  passes.
- [fix] Seed `000_template_app_roles.sql`: remove obsolete `INSERT` into
  non-existent `public.app_roles` (roles are the `app_role` enum); restores
  `supabase db reset` seed phase.
- [fix] `codegen:backend --check` now prints a clear message when all domains
  have `codegen: false` (previously looked like a silent success).
- [fix] Add `publint` / `check:exports` to `@workspace/codegen-tools` so
  pre-push `pnpm -r --filter './packages/*' exec publint` succeeds (same pattern
  as other workspace packages).

### Changed

- [refactor] Codegen fixtures: drop versioned `domain-map.fixture.json`; unit
  tests build `domain-map` inline from `database.types.mock.ts` tables; add
  `packages/codegen-tools/fixtures/README.md`.

### Added

- [feat] `pnpm codegen:snapshot-types` and `packages/codegen-tools/workspace/`
  (gitignored) for optional frozen `database.types` copies; docs and skills
  state that `config/domain-map.json` remains the canonical map path.
- [feat] Backend codegen toolkit: `config/domain-map.json`,
  `packages/codegen-tools` (Zod schema, TS parser for `public.Tables`, validate
  - sync CLIs), `pnpm codegen:domain-map:validate`,
    `pnpm codegen:domain-map:sync`, `pnpm codegen:backend`,
    `pnpm supabase:types:linked`; fixtures under
    `packages/codegen-tools/fixtures/`; skills `backend-domain-map` and
    `backend-domain-codegen-init` with Cursor symlinks; guide
    `docs/guides/backend-codegen.md`.
- [docs] Clarify canonical Server Action patterns in
  `docs/architecture/backend.md` (thin `server-only` helpers vs
  `pnpm action:new` for new app-facing actions).
- [docs] Link backend codegen guide from `docs/README.md`; add optional codegen
  steps to `docs/guides/migration-workflow.md`.
- [feat] Root script `pnpm test:db:all` → `test:integration` + `test:rls` +
  `test:db` (Vitest + pgTAP); documented in testing, command-reference,
  database, tdd, and `supabase/tests/AGENTS.md`.
- [feat] Root script `pnpm test:db` → `pnpm exec supabase test db` (pgTAP); docs
  and `supabase/tests/AGENTS.md` aligned; fix `test:db` vs `test:sql`
  descriptions in `database.md` and `tdd.md`.
- [feat] Extend `pnpm check:forbidden` to reject `"use server"` and
  `apps/*/actions/` under `apps/`, with errors pointing at
  `packages/supabase-data/src/actions/` and
  `docs/architecture/CRITICAL-RULES.md`.
- [feat] Enforce composition-package filename suffixes (`*.component.tsx`,
  `*.hook.ts`, `*.provider.tsx`) under `packages/brand`, `packages/core`,
  `packages/forms`, and `packages/seo` (never `packages/ui`); forbid those
  suffixes under `apps/`. Documented in
  `docs/standards/package-file-suffixes.md`.

### Security

- [security] `pnpm.overrides`: require `brace-expansion` >=5.0.5
  (GHSA-f886-m6hf-6m8v via `@sentry/nextjs` → `minimatch`); `pnpm audit` clean
  at default severity.
- [security] Add root `pnpm.overrides` for transitive advisories (handlebars,
  basic-ftp, lodash, minimatch, path-to-regexp, picomatch); bump `packages/ui`
  `@turbo/gen` to match workspace `turbo` so `pnpm audit --audit-level=high`
  passes.

### Changed

- [fix] TypeScript `tsconfig`: remove deprecated `compilerOptions.baseUrl`; use
  `paths` only (resolved relative to each config file); fix `@workspace/*` in
  `packages/typescript-config/base.json` to `../../packages/*`; add `paths`
  wildcards for `seo` and `tests` where `baseUrl` was the only anchor; update
  `docs/tools/typescript-strict.md` example.
- [docs] Expand `docs/git-hooks.md`: IDE vs Git hooks, pre-commit vs pre-push,
  auto-fix vs blocking failures, correct manual commands (`lefthook run`), and
  lint-staged vs full-repo pre-commit.
- [fix] Pre-commit `lefthook.yml`: full-repo `pnpm format` +
  `pnpm exec oxlint --fix` (not `{staged_files}`); `parallel: false`;
  `stage_fixed: true`; update `docs/git-hooks.md` (Lefthook #1369 note
  retained).
- [fix] Stub modules: `.oxfmtrc.json` and `.oxlintrc.json` ignore
  `server-only-stub.ts` and `packages/brand` `index.ts` (oxfmt keeps
  `export {}`; `oxlint --fix` no longer strips it); note in
  `docs/tools/oxlint-oxfmt.md`.
- [docs] Align `docs/reference/stack.md` bundler notes with `apps/example`
  (`next dev` / `next build` use **Turbopack**, not Webpack).
- [chore] Bump workspace dependencies (Next 16.2.2, next-intl 4.9, Tailwind 4.2,
  Turbo 2.9, Vitest 4.x in example/tests/supabase-data/test-utils, Supabase JS
  2.101 / SSR 0.10, jsdom 29, vite-tsconfig-paths 6, Sentry/Posthog patches);
  re-export `Json` from `database.ts`; cast observability `metadata` insert to
  `Json` for stricter client typings; refresh `docs/reference/stack.md` and add
  maintainer notes in `docs/CONTRIBUTING.md`.
- [docs] Exclude `packages/ui/**` from Oxlint via root `ignorePatterns`;
  document policy in `docs/tools/oxlint-oxfmt.md` and `AGENTS.md` (vendored
  shadcn, GR-001).
- [refactor] Align `@workspace/brand` and `@workspace/seo` dependencies with
  Knip: `react` / `react-dom` as peer dependencies in `brand`; remove unused
  `next` from `seo` (pure URL/JSON-LD helpers).
- [docs] Add `packages/AGENTS.md`, `packages/README.md`,
  `packages/forms/AGENTS.md`, `packages/seo/AGENTS.md`; expand
  `docs/standards/package-file-suffixes.md` (package table, checklist);
  cross-link README, CONTRIBUTING, skills, golden-rules.
- [refactor] Rename `brand` / `core` / `forms` source files to match suffix
  conventions; `package.json` export keys unchanged.
- [docs] Align Cursor Agent Skills with official layout:
  `skills/<name>/SKILL.md` with YAML frontmatter;
  `.cursor/skills/<name>/SKILL.md` symlinks; remove flat `.mdc` skills; add
  `llm-to-llm-prompt` skill; update skills index, AGENTS.md, and root README.
- [docs] Align depcruise examples with `apps/<app>/app/` (replace `apps/*/src`
  where the template has no `src/`).

### Fixed

- [fix] Add `publint` and `check:exports` to `@workspace/seo` so `pre-push`
  `pnpm -r exec publint` matches other packages.
- [fix] `packages/typescript-config/base.json`: add `es2023` to
  `compilerOptions.lib` so `Array#toSorted()` typechecks (Oxlint `--fix` emits
  `toSorted`); aligns TS with immutable-array APIs.
- [fix] `.gitignore`: ignore `.idea/` and `*.log`; restore `export {}` on Vitest
  `server-only` stub (Oxlint `unicorn/no-empty-file`).
