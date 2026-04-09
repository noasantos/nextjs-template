> **Contributors without Cursor:** Same rule as
> [`.cursor/rules/type-escapes.mdc`](../../../.cursor/rules/type-escapes.mdc).
> Regenerate: `node scripts/ci/sync-cursor-rules-to-docs.mjs`.

---

# Type Escape Policy

## Rule

TypeScript type escapes (`as never`, `as unknown as`, `@ts-ignore`,
`@ts-expect-error`) are **forbidden without justification**. Every escape that
cannot be removed must be annotated with a `// @type-escape:` comment on the
line immediately above it.

The CI script `scripts/ci/check-type-escapes.mjs` enforces this for all
production source files. Violations block commits.

## Permitted categories

### 1. Library adapter boundary

Third-party libraries sometimes use opaque generics or overloads that make
structurally equivalent types non-assignable. The escape documents which library
is responsible and why fixing upstream is not viable.

Example:

```typescript
// @type-escape: Resolver<z.input<TSchema>&FieldValues,…> not assignable to Resolver<InferInputOrDefault<TSchema,any>,…> — Standard Schema vs Zod method derivation paths diverge
return useHookFormAction(action, createResolver(schema) as never, { … })
```

### 2. Generated code template

Code generators sometimes emit a cast inside a string template because the full
generic chain is not evaluable in a template literal context.

Example:

```typescript
// @type-escape: distributive mapped type not viable inside a template-literal codegen string
;(data as never)[key]
```

### 3. Supabase RPC type sync

`supabase-js` RPC call signatures are generated from the DB schema but not
always kept in sync with custom RPCs or views. Until the types are regenerated,
a cast is acceptable.

Example:

```typescript
// @type-escape: supabase-js RPC types not yet synced with auth_is_admin RPC signature
const result = (await supabase.rpc("auth_is_admin")) as unknown as {
  data: boolean
  error: unknown
}
```

## What is NOT permitted

- Silencing an error because fixing the root cause is inconvenient
- Using `as any` anywhere in production code (oxlint
  `@typescript-eslint/no-explicit-any` catches this)
- Adding `@ts-ignore` without first investigating whether the types can be fixed

## Test files

The CI gate intentionally excludes `tests/` directories. Use typed fixture
helpers (e.g. `makeSupabaseStub`, `makeClaims`) to consolidate casts to a single
annotated site rather than repeating raw casts throughout test bodies.

## Adding a new escape

1. Confirm the escape cannot be removed by fixing types at the source.
2. Add `// @type-escape: <library/reason> — <one-line explanation>` on the line
   above.
3. Document the root cause in a comment if the explanation requires more
   context.
