# Auth Invariants

Short contract for humans and code assistants.

## Server-side rules

- Use `getClaims()` for server authorization and protected-route decisions.
- Do **not** use `getSession()` for server authorization. The helper remains
  internal-only for narrow session inspection and tests.
- Session refresh and cookie propagation belong in root `proxy.ts`, using
  `@workspace/supabase-auth/proxy/update-session`.
- Create request-scoped Supabase auth clients inside server work; do not cache
  them across requests.

## Boundary validation

- Validate externally influenced inputs at the route/action boundary.
- Shared schemas belong in workspace packages when the boundary is part of
  shared auth/data behavior.
- Internal functions should receive typed, already-validated values.

The auth callback, confirm, and logout handlers now use shared schemas from
[`@workspace/supabase-auth/shared/auth-route-input.schema`](../../packages/supabase-auth/src/shared/auth-route-input.schema.ts).

## Sensitive-route abuse protection

Sensitive auth-adjacent routes should call a protection hook before hitting
GoTrue or other external systems.

- Hook:
  [`protectSensitiveAuthRoute`](../../packages/supabase-auth/src/server/sensitive-route-protection.ts)
- **`NODE_ENV=production`** without `AUTH_RATE_LIMIT_MODE=memory` (or `off`) →
  **fail closed**: handlers return **503** with `Retry-After` until you opt in
  (security-first default for forks).
- **`AUTH_RATE_LIMIT_MODE=memory`** → in-process windowed limits (suitable for
  **local dev** and **single-instance** deployments only; not coherent across
  serverless instances).
- **`AUTH_RATE_LIMIT_MODE=off`** → pass-through (documented escape hatch;
  **not** for production).
- Non-production (`development`, `test`, etc.) → **memory** limiter by default
  so local and CI work without extra env.

Production expectation: replace or wrap the hook with a **durable** store (e.g.
Redis / Upstash) behind the same `SensitiveRouteProtector` interface when you
outgrow `memory`.

When throttling:

- fail closed with **429** (rate limited) or **503** (abuse protection not
  configured)
- emit a `Retry-After` header
- log the denial path without logging secrets or tokens

## Client IP for rate limiting (trusted proxy)

Bucketing uses the first available of:

1. `cf-connecting-ip` (Cloudflare)
2. `x-vercel-forwarded-for` (Vercel)
3. `x-real-ip` (common reverse proxies)
4. First hop of `x-forwarded-for`

**Threat:** clients can spoof `x-forwarded-for` if your app receives their raw
request. Terminate TLS and **normalize or strip** forwarding headers at your
edge (Vercel, nginx, Cloudflare) so the app only sees platform-trusted values.

## Next.js 16 naming

Use root `proxy.ts` terminology, not legacy `middleware.ts`, when documenting
request interception in this repo.
