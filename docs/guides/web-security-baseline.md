# Web Security Baseline

Template-safe defaults for Next.js apps in this monorepo.

## What the template now enforces

- `Referrer-Policy: strict-origin-when-cross-origin`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Resource-Policy: same-origin`
- `Permissions-Policy` with browser sensors/camera/mic/payment disabled by
  default
- `Content-Security-Policy-Report-Only` on all routes in `apps/example` (unless
  enforcing CSP is enabled; see below)

### HSTS (edge only)

Do **not** set `Strict-Transport-Security` in Next.js config unless the app is
always served over HTTPS on a single canonical host. Prefer **HSTS at the CDN /
hosting edge** (e.g. Vercel) once preload and subdomain policy are understood.

## CSP stance

The template ships a **report-only** CSP starter instead of a strict enforcing
policy because App Router apps often need nonces, hashes, or product-specific
allowlists before an enforcing CSP is safe.

**Opt-in enforcing CSP:** set root `CSP_ENFORCE=1` (see
[`.env.example`](../../.env.example)). The app then:

- omits `Content-Security-Policy-Report-Only` from
  [`apps/example/next.config.mjs`](../../apps/example/next.config.mjs) for a
  single CSP source of truth
- generates a per-request nonce in
  [`apps/example/proxy.ts`](../../apps/example/proxy.ts), sets
  `Content-Security-Policy` on the request and response (Next.js 16 reads the
  nonce from the policy for framework scripts)
- calls `connection()` in
  [`apps/example/app/[locale]/layout.tsx`](../../apps/example/app/[locale]/layout.tsx)
  so routes stay dynamically rendered when nonces are required

Break-glass: `Cross-Origin-Opener-Policy: same-origin` can break flows that rely
on cross-origin `window.opener` (some OAuth or payment popups). Prefer
`same-origin-allow-popups` only after testing, or scope header changes to routes
that do not open those popups.

Current starter goals:

- keep obviously safe directives explicit (`base-uri`, `form-action`,
  `frame-ancestors`, `object-src`)
- avoid product-specific third-party domains
- allow local Supabase / local dev websocket traffic without telling maintainers
  to weaken production policy

## Fork maintainer path

1. Start from the report-only policy in
   [`apps/example/lib/security-headers.mjs`](../../apps/example/lib/security-headers.mjs).
2. Replace broad `script-src`, `style-src`, and `connect-src` allowances with
   nonces, hashes, or explicit origins once your integrations are known.
3. Keep `frame-ancestors 'none'` unless the product must be embedded.
4. Add HSTS only at the deployment edge when every production hostname is
   HTTPS-only and preload expectations are understood.

## Scope note

`apps/docs` in this template is documentation content, not a runtime Next.js
app. New Next apps should copy the same header baseline instead of inventing
their own defaults.
