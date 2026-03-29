# @workspace/vitest-config

Shared Vitest presets for this monorepo.

## Exports

| Export | Use |
|--------|-----|
| `@workspace/vitest-config/node` | Node/unit tests (`createNodeProject`) — coverage thresholds per [GR-007](../../docs/standards/golden-rules.md#gr-007-test-coverage-thresholds) |
| `@workspace/vitest-config/db` | Integration / DB projects (`createDbProject`) |
| `@workspace/vitest-config/react` | React component tests |

Setup files (`setup-node`, `setup-dom`, `setup-db`) resolve to `packages/test-utils/src/vitest/*` via a path relative to this package’s `src/` so **`@workspace/vitest-config` does not depend on `@workspace/test-utils` in `package.json`** (avoids a workspace cycle with `test-utils` → `supabase-infra` → `vitest-config`).

Root multi-project entry (optional): [vitest.config.mts](../../vitest.config.mts). DB integration/RLS: [`@workspace/tests`](../../tests/package.json). Process: [TDD](../../docs/architecture/tdd.md), [Testing](../../docs/architecture/testing.md).
