# ADR-001: Monorepo Structure with Zero-Barrel Policy

**Date:** 2026-03-11  
**Status:** Accepted (historical); **current layout and package names supersede the Vite-era details below**  
**Supersedes details:** [docs/standards/repository-standards.md](../../standards/repository-standards.md), [system.md](../system.md), [apps/README.md](../../apps/README.md)

---

## Context

We are implementing a frontend-focused monorepo (originally Vite-era; **now Next.js apps + `pnpm` workspaces**) with strong engineering standards. The codebase must be predictable for humans and machines alike, with explicit architectural boundaries and AI-friendly conventions.

Key requirements:
- Multiple apps sharing common code — **today** see [apps/README.md](../../apps/README.md): a single template app **`example`** (default dev port **3000**) with marketing and auth (`/sign-in`, callbacks). Add more apps under `apps/` when you need them.
- Historical draft below listed 517x Vite ports and split apps; **ignore those port numbers** for local dev.
- Strong typing with TypeScript strict mode
- Clear import boundaries to prevent circular dependencies
- Machine-checkable rules for AI agents and human developers
- Fast builds with proper caching and task orchestration

---

## Decision

We will use **pnpm workspaces** with **Turborepo** for task orchestration, implementing a **zero-barrel policy** with explicit subpath exports.

### Structure

```
<repo>/
├── apps/
│   └── example/       # Template Next.js app (rename when you ship)
├── packages/
│   ├── ui/            # @workspace/ui — shadcn primitives
│   ├── supabase-auth/, supabase-data/, supabase-infra/
│   ├── eslint-config/
│   ├── typescript-config/
│   └── vitest-config/
├── docs/
│   ├── standards/              # repository-standards, golden-rules, anti-patterns
│   ├── reference/              # stack, command-reference
│   ├── guides/                 # supabase-setup, migration-workflow, …
│   ├── architecture/           # system, backend, database, TDD, testing, decisions/
│   └── getting-started.md
└── AGENTS.md          # Canonical AI instructions
```

### Package Exports (Zero-Barrel)

Each package uses explicit subpath exports, NO barrel files:

```json
{
  "name": "@workspace/types",
  "exports": {
    "./schemas/user": "./src/schemas/user.ts"
  }
}
```

**Imports are always explicit:**
```typescript
import { UserSchema } from "@workspace/types/schemas/user";
// NOT: import { UserSchema } from "@workspace/types";
```

### TypeScript Configuration

All strict flags enabled in `packages/typescript-config/base.json`:
- `strict: true`
- `exactOptionalPropertyTypes: true`
- `noUncheckedIndexedAccess: true`
- `noImplicitReturns: true`
- `noFallthroughCasesInSwitch: true`

### ESLint Rules

Key rules enforced:
- `max-lines`: warn at 250, error at 300
- `no-console`: warn for log/warn/error
- `@typescript-eslint/consistent-type-assertions`: error
- `no-restricted-imports`: block barrel imports

---

## Consequences

### Positive

1. **Explicit Dependencies:** Every import path clearly shows what is being imported and from where
2. **Better Tree-Shaking:** Bundlers can eliminate unused code more effectively
3. **Machine-Checkable:** ESLint can enforce import boundaries automatically
4. **AI-Friendly:** Clear patterns for AI agents to follow
5. **Fast Builds:** Turborepo caching and parallelization
6. **Type Safety:** Strict TypeScript catches bugs at compile time

### Negative

1. **More Verbose Imports:** Developers must type longer import paths
2. **Migration Overhead:** Converting existing barrel imports requires bulk changes
3. **Learning Curve:** New developers must learn subpath export patterns
4. **Package.json Complexity:** Export maps are more complex than simple main fields

### Neutral

1. **File Structure Discipline:** Requires consistent directory naming conventions
2. **Documentation Overhead:** Must maintain ADRs and golden rules
3. **Config Package Management:** Shared configs must be versioned carefully

---

## Related

- **GR-001:** Zero-Barrel Policy (Golden Rule)
- **BAD-002:** Barrel Files (Anti-Pattern)
- **AGENTS.md:** Canonical AI instructions

---

## Enforcement

1. **ESLint:** `no-restricted-imports` blocks barrel imports
2. **CI:** Fails on lint errors and type errors
3. **Pre-commit:** Lint-staged runs on staged files
4. **Code Review:** Reject violations of zero-barrel policy
