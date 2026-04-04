# Type Safety Policy

> **Status:** Active  
> **Applies to:** All packages and apps under `nextjs-template/`  
> **Enforcement:** Oxlint (`typescript/no-explicit-any`,
> `typescript/no-unsafe-type-assertion`,
> `typescript/consistent-type-assertions`, `typescript/no-non-null-assertion`),
> `scripts/ci/check-type-escapes.mjs`

---

## Principles

This codebase operates under TypeScript's strictest configuration: `strict`,
`exactOptionalPropertyTypes`, `noUncheckedIndexedAccess`, `isolatedModules`.

Type assertions are **not** a convenience tool. They are an explicit override of
the compiler, accepted only when the compiler cannot be made to understand the
correct shape without a cast that introduces no runtime risk.

**Default posture:** If TypeScript rejects your code, fix the types — do not
silence the compiler.

---

## Permitted Escape Hatches

The following escape patterns are **permitted** under the conditions described.
All permitted uses must be annotated with `// @type-escape:` (see Annotation
Standard below).

### 1. `as never` — SDK/Client library boundary mismatch

**When permitted:** The TypeScript types shipped by an external library (e.g.
`@supabase/supabase-js`) do not accept a valid call shape due to upstream typing
limitations, not due to a real type error in your code.

**Conditions:**

- The cast is at the outermost call site to the external API only (not inside
  domain logic)
- The argument or return value is structurally correct at runtime
- A `// @type-escape: BOUNDARY —` comment explains the upstream limitation
- A tracking note (GitHub issue, TODO) references when it can be removed

**Example (current repo — justified):**

```ts
// @type-escape: BOUNDARY — Supabase mfa.enroll does not type optional spread args.
// Remove when supabase-js#XXXX is resolved.
return supabase.auth.mfa.enroll({ factorType: "totp", ...opts } as never)
```

**Not permitted:**

- `as never` inside domain logic, data transformations, or business rules
- `as never` to silence a real type error (wrong shape, missing field)
- `as never` as a shortcut to avoid writing the correct type

### 2. `as unknown as TargetType` — Typed mapper/adapter pattern

**When permitted:** A value enters the system at an external boundary (database
row, JWT payload, SDK response) where the upstream type is too wide or
incorrect, and you have a single dedicated mapper function that performs the
cast once.

**Conditions:**

- The cast lives inside a mapper or adapter function — **not** at the call site
- The mapper is the only place this cast appears for that type
- A runtime validation (Zod) or structural guard precedes the cast where
  feasible
- A `// @type-escape: ADAPTER —` comment is present

**Example:**

```ts
// @type-escape: ADAPTER — PostgREST embed returns loose object; mapper is the
// single cast site. Validated by SessionWithJoinsSchema.parse upstream.
function mapSessionRow(row: RawSessionRow): SessionWithJoins {
  return row as unknown as SessionWithJoins
}
```

**Not permitted:**

- `as unknown as TargetType` scattered across multiple call sites for the same
  type
- Using this pattern to bypass a Zod parse that should exist

### 3. `as SomeType` narrowing cast — Post-guard or post-parse assertion

**When permitted:** After a runtime type guard or Zod parse has narrowed the
actual runtime shape, but TypeScript's control flow cannot infer the result type
automatically.

**Conditions:**

- A type guard (`if (isX(value))`, `typeof`, `instanceof`) or Zod `parse`
  precedes the cast
- The cast narrows to a more specific type, never to a broader one
- A `// @type-escape: NARROWING —` comment is present

**Not permitted:**

- Narrowing cast without a preceding guard (this is what
  `no-unsafe-type-assertion` catches)
- Casting to a type wider than the actual value

### 4. `@ts-expect-error` — Known upstream bug with tracked resolution

**When permitted:** A library ships broken types for a specific API that you are
using correctly. Not a workaround for your own type errors.

**Conditions:**

- The comment following `@ts-expect-error` includes the upstream issue link
- A `// @type-escape: TS-EXPECT —` comment on the line above explains context
- Reviewed in PR and approved

**Not permitted:**

- `@ts-ignore` — use `@ts-expect-error` instead (fails if the error goes away)
- Using either to silence errors in your own domain code

### 5. `!` non-null assertion — Guarded context only

**When permitted:** The value has been proven non-null by a guard in the same
scope, but TypeScript's narrowing does not persist across the call boundary.

**Conditions:**

- A `null` / `undefined` check immediately precedes the usage in the same
  function
- The assertion is on a value that cannot realistically change between the guard
  and usage
- In test files (no annotation required — lint is relaxed for tests)

**Not permitted:**

- `!` as a shortcut to avoid handling the null/undefined case
- `!` on function return values without a local null check
- `!` in production code without a `// @type-escape: NON-NULL —` comment

---

## Prohibited Patterns

These patterns are **never** permitted in production source (`apps/`,
`packages/` — not test files):

| Pattern                                                              | Reason                                                            |
| -------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `as any`                                                             | Completely disables type checking; no justification exists        |
| `{ } as SomeType` on object literals                                 | Hides missing properties at construction; use `satisfies`         |
| `(value as any).property`                                            | Unsafe member access; fix the type instead                        |
| `@ts-ignore`                                                         | Suppresses errors silently; use `@ts-expect-error` if unavoidable |
| `as never` inside domain logic                                       | Signals a modeling failure; fix the types                         |
| Multiple `as unknown as T` for the same type at different call sites | Isolate to a single mapper                                        |

---

## Annotation Standard

Every permitted escape hatch in production source **must** be preceded by a
comment on the immediately preceding line in this format:

```
// @type-escape: <CATEGORY> — <reason>. [<tracking reference if applicable>]
```

Categories: `BOUNDARY`, `ADAPTER`, `NARROWING`, `TS-EXPECT`, `NON-NULL`

This annotation is machine-checked by `scripts/ci/check-type-escapes.mjs`.
Unannotated escape hatches will fail pre-commit and CI.

---

## Enforcement

| Mechanism                                      | What it catches                 | Where it runs  |
| ---------------------------------------------- | ------------------------------- | -------------- |
| `typescript/no-explicit-any: error`            | `as any`, explicit `any` type   | Pre-commit, CI |
| `typescript/no-non-null-assertion: error`      | `!` assertions                  | Pre-commit, CI |
| `typescript/no-unsafe-type-assertion: error`   | Narrowing casts without guards  | Pre-commit, CI |
| `typescript/consistent-type-assertions: error` | Object literal casts `{ } as T` | Pre-commit, CI |
| `scripts/ci/check-type-escapes.mjs`            | Unannotated escape hatches      | Pre-commit, CI |
| `turbo typecheck`                              | Full `tsc --noEmit` per package | CI             |

**Test files** (`*.test.ts`, `*.test.tsx`, `*.spec.ts`): `no-explicit-any`,
`no-non-null-assertion`, `no-unsafe-type-assertion`,
`consistent-type-assertions` are **relaxed**. Test doubles and mock constructors
are exempt. The `@type-escape` annotation is **not required** in test files.

---

## Preferred Alternatives

Before reaching for a cast, exhaust these options in order:

1. **Fix the type** — the upstream type is wrong; extend or augment it
2. **Type guard** — `function isX(v: unknown): v is X { ... }`
3. **Zod parse** — `XSchema.parse(value)` at the boundary; derive
   `type X = z.infer<typeof XSchema>`
4. **`satisfies`** — `const x = { ... } satisfies SomeInterface` — validates
   without widening
5. **Generic constraint** — tighten the function signature instead of casting
   the result
6. **Module augmentation** — extend library types when upstream is missing a
   method
7. **Typed adapter function** — one cast inside a named function, zero casts at
   call sites

---

## Current Escape Hatch Inventory

> Last updated: 2026-04-04  
> Source: `grep -rn "@type-escape" packages/ apps/ --include="*.ts" --include="*.tsx"`

| File                                                                 | Line | Category | Reason                                          | Tracking |
| -------------------------------------------------------------------- | ---- | -------- | ----------------------------------------------- | -------- |
| `packages/supabase-auth/src/browser/enroll-totp-factor.ts`           | 19   | BOUNDARY | Supabase mfa.enroll optional spread args        | —        |
| `packages/supabase-auth/src/session/get-access.ts`                   | 67   | BOUNDARY | Supabase rpc() args vs generated Database types | —        |
| `packages/supabase-data/src/actions/user-access/sync-user-access.ts` | 57   | BOUNDARY | Supabase admin rpc() args                       | —        |
| `packages/logging/src/server.ts`                                     | 359  | BOUNDARY | Supabase insert row vs Database Insert type     | —        |

> This table is informational. The machine-authoritative source is
> `check-type-escapes.mjs`.

---

## Review and Approval

Any PR that introduces a new `// @type-escape:` annotation must:

1. Include the annotation with full category and reason
2. Include a comment in the PR description explaining why alternatives were
   exhausted
3. Be approved by a maintainer who is not the author

PRs that remove a `// @type-escape:` annotation (because the upstream type was
fixed or the code was redesigned) are encouraged and require no additional
review overhead.
