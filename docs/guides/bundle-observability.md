# Bundle Observability

Use the template script before adding new client dependencies or moving logic client-side.

## Command

```bash
pnpm bundle:analyze:example
```

That builds `apps/example`, then summarizes emitted client JavaScript from the generated Next build manifests.

## Checklist

- Keep data loading and auth decisions on the server whenever possible.
- Add `'use client'` only where browser APIs, local interactivity, or client-only libraries require it.
- Do not pull server-only helpers or heavy SDKs into client component graphs.
- Lazy-load heavy client-only features when they are not needed for initial render.

## Reading the output

- Watch the total emitted JavaScript line first.
- Review the largest chunk entries before merging new client libraries.
- If a chunk grows unexpectedly, inspect whether a shared component crossed the server/client boundary unnecessarily.
