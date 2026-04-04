# Changelog

## [Unreleased]

### Added

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

- [security] Add root `pnpm.overrides` for transitive advisories (handlebars,
  basic-ftp, lodash, minimatch, path-to-regexp, picomatch); bump `packages/ui`
  `@turbo/gen` to match workspace `turbo` so `pnpm audit --audit-level=high`
  passes.

### Changed

- [fix] Pre-commit `lefthook.yml`: pass `{staged_files}` to `oxfmt` and `oxlint`
  so hooks do not lint/format the entire repo (was failing commits with hundreds
  of Oxlint issues outside the staged set); clarify in `docs/git-hooks.md`.
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
