# Command reference (root)

Root **`package.json`** scripts (authoritative). Prefer `pnpm <script>` from the
repository root.

## Quality & CI

| Script                           | Purpose                                                      |
| -------------------------------- | ------------------------------------------------------------ |
| `pnpm lint`                      | Oxlint via Turborepo                                         |
| `pnpm typecheck`                 | TypeScript across packages/apps                              |
| `pnpm format`                    | Format with oxfmt                                            |
| `pnpm format:check`              | Check formatting                                             |
| `pnpm test`                      | Unit tests                                                   |
| `pnpm test:coverage`             | Unit tests + coverage                                        |
| `pnpm test:integration`          | Integration tests                                            |
| `pnpm test:rls`                  | RLS tests                                                    |
| `pnpm test:db`                   | pgTAP / `supabase test db` (local DB)                        |
| `pnpm test:db:all`               | `test:integration` + `test:rls` + `test:db` (Vitest + pgTAP) |
| `pnpm test:all`                  | Coverage + SQL tests                                         |
| `pnpm check:forbidden`           | Forbidden paths / patterns (includes architecture guards)    |
| `pnpm check-forbidden-patterns`  | Shell-based pattern checks                                   |
| `pnpm check:workspace-imports`   | No `../` in apps/packages                                    |
| `pnpm check:cursor-rules-parity` | `.cursor/rules` ↔ `docs/standards/rules`                     |
| `pnpm check:security-smells`     | Security smell scan                                          |
| `pnpm check:docs-drift`          | Docs links + script drift                                    |
| `pnpm check-type-escapes`        | `@type-escape` annotations                                   |
| `pnpm knip`                      | Dead code (production)                                       |
| `pnpm workflow`                  | lint → imports → rules parity → typecheck → build → format   |

## Supabase CLI

The Supabase CLI is available as a dev dependency. Prefer
**`pnpm exec supabase <subcommand>`** (e.g. `pnpm test:db` for pgTAP) so the
version matches `package.json`.

## Scaffolding

| Script                                  | Purpose                 |
| --------------------------------------- | ----------------------- |
| `pnpm action:new -- <module> <name>`    | New Server Action       |
| `pnpm edge:new -- <name>`               | New Edge Function       |
| `pnpm supabase:migration:new -- <name>` | New migration (stamped) |

## See also

- [Root README](../../README.md)
- [Getting started](../getting-started.md)
- [Testing](./../architecture/testing.md)
