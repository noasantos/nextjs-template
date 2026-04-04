# SEO and discoverability

Template-level guide for **forkers** of this monorepo. The goal is to **prevent
silent mistakes** (broken Open Graph URLs, indexed auth pages, wrong `lang`)
rather than to “rank” the template itself.

**B2B** forks often want a single-locale marketing site, strong **Organization**
JSON-LD, and **noindexed** admin. **B2C** forks may add locales, richer
sitemaps, **Product** / **Review** schema, and public profile URLs—use the
callouts below and [structured-data.md](./structured-data.md).

---

## Overview

- **Code (minimal)** lives in `apps/example`: `metadataBase`, route-group
  metadata, `robots.ts`, `sitemap.ts`, `manifest.ts`, and stubs for JSON-LD /
  dynamic metadata.
- **Docs (this file + checklists)** explain _why_ each default exists and what
  to change at fork time.
- **Per-app rule:** each `apps/*` deployable that is public on the web should
  own its own `app/robots.ts` and `app/sitemap.ts`—do not assume another app’s
  SEO files apply.

---

## Environment variables for SEO

| Variable                     | Role                                                                                                                                                                                                                |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_SITE_URL`       | Canonical **https** origin for `metadataBase`, absolute OG URLs, sitemap entries, and canonical resolution. **Required** for `pnpm build` when `NODE_ENV=production` (validated in `apps/example/next.config.mjs`). |
| `NEXT_PUBLIC_AUTH_APP_URL`   | Auth redirects, callbacks, allowed origins—**do not** repurpose for canonical marketing URL; they may differ (e.g. `auth.example.com` vs `example.com`).                                                            |
| `NEXT_PUBLIC_DEFAULT_LOCALE` | Document only—**must match** `defaultLocale` in `apps/example/i18n/routing.ts`. `<html lang>` comes from the `[locale]` segment.                                                                                    |
| `ROBOTS_ALLOW`               | Must be exactly `true` to allow indexing helpers (`robots.txt` allow rules + non-empty `sitemap.xml`) in `apps/example`. Otherwise crawlers get `Disallow: /` and an empty sitemap.                                 |

See root [`.env.example`](../../.env.example) for comments.

---

## metadataBase pattern

Next.js resolves **relative** Open Graph and Twitter image URLs against
`metadataBase`. Without it, social cards often break on first deploy.

The example app uses:

- `getSiteUrl()` from `apps/example/lib/site-url.ts` — `NEXT_PUBLIC_SITE_URL` →
  fallback `NEXT_PUBLIC_AUTH_APP_URL` → `http://localhost:3000` for local dev
  only.
- `metadataBase: new URL(\`${siteUrl}/\`)`in`apps/example/app/[locale]/layout.tsx`.

Production builds **must** set `NEXT_PUBLIC_SITE_URL` to a **public https**
hostname (see `next.config.mjs`).

---

## Route group metadata inheritance

| Segment                          | Default                                                                                               | Rationale                                                  |
| -------------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Root `app/layout.tsx`            | Pass-through only (`children`)                                                                        | Satisfies Next.js root layout; no `<html>` here.           |
| `app/[locale]/layout.tsx`        | `metadataBase`, title template, OG/Twitter, `alternates.languages` (hreflang), `<html lang={locale}>` | Locale-aware defaults via `next-intl` + `getTranslations`. |
| `app/[locale]/(marketing)/`      | Inherits locale layout; pages may override or use `generateMetadata`                                  | Public indexable content.                                  |
| `app/[locale]/(auth)/layout.tsx` | `robots: { index: false, follow: false }`                                                             | Login, reset, MFA—thin or sensitive; avoid SERP noise.     |

**Magic link (`/magic-link`):** the template treats the whole `(auth)` group as
**noindex**. If your product uses `/magic-link` as a **permanent** marketing
landing page (not a token-consumption URL), move it out of `(auth)` or override
`metadata` on that route only—see
[preview-environments.md](./preview-environments.md) for crawl considerations.

**Staff-only areas:** when you add an admin or dashboard segment, give its
`layout.tsx` the same `robots: { index: false, follow: false }` pattern as
`(auth)`.

---

## Robots policy

`apps/example/app/robots.ts`:

- `ROBOTS_ALLOW !== 'true'` → `Disallow: /` (preview, staging, local, or
  misconfigured prod).
- `ROBOTS_ALLOW === 'true'` → allow `/`, `disallow` auth paths (with and without
  locale prefix), expose `sitemap` and `host`.

Auth layouts still send **`noindex`** via metadata; robots rules are an extra
layer.

---

## Sitemap

`apps/example/app/sitemap.ts` lists **marketing** URLs from **`PUBLIC_ROUTES`**
in `apps/example/lib/public-routes.ts`, **per configured locale** (default
locale uses no URL prefix when `localePrefix` is `as-needed`). Entries include
`alternates.languages` for hreflang. When `ROBOTS_ALLOW` is not `true`, it
returns **`[]`** so you do not submit preview URLs to Search Console by
accident.

**When adding a new public page, register it in `lib/public-routes.ts`.**
Failing to do so silently omits it from the sitemap.

**B2C:** extend with blog posts, products, or more locales—fetch in `sitemap()`
(or split with `generateSitemaps` for very large sets). Never add `/sign-in` or
other auth paths.

---

## Open Graph, Twitter, and OG image files

Defaults live in `app/[locale]/layout.tsx`. The **marketing** segment ships
**`app/[locale]/(marketing)/opengraph-image.tsx`**: Next.js file convention
generates `og:image` for that route tree (dynamic copy from `messages` via
`next-intl`).

**Relationship:**

- **`opengraph-image.tsx`** in a segment takes precedence for `og:image` on
  routes under that segment.
- **`public/og-default.png`** is a tracked **1200×630** placeholder so any
  direct reference or route **without** its own `opengraph-image` does not 404.
  Forks should replace it with a branded asset (or add per-segment
  `opengraph-image.tsx` files).

At fork time:

- Replace **title**, **description**, **siteName** in `messages/*.json`.
- Replace **`og-default.png`** or extend dynamic OG per route.
- Validate with [OpenGraph.xyz](https://www.opengraph.xyz) or the LinkedIn post
  inspector after deploy.

### Fork checklist — OG assets

- [ ] **`apps/example/public/og-default.png`** — 1200×630, keep under ~200KB if
      possible (WebP or PNG); replace with branded art at fork.
- [ ] **`(marketing)/opengraph-image.tsx`** — FORK: adjust layout, fonts, and
      branding; add more `opengraph-image.tsx` files under other segments when
      you add public pages (blog, pricing, etc.).

**Dynamic OG (B2C / content sites):** the template uses `next/og`
(`ImageResponse`) in `(marketing)/opengraph-image.tsx`. See
[Next.js Metadata Files](https://nextjs.org/docs/app/api-reference/file-conventions/metadata/opengraph-image)
and
[ImageResponse](https://nextjs.org/docs/app/api-reference/functions/image-response).

---

## Canonical URLs and `@workspace/seo`

Shared helpers live in **`packages/seo`** (`buildCanonicalUrl`,
`buildAlternateLanguages`, `buildJsonLd`). They take **`siteUrl` and locale
parameters**—they do **not** import app-local `i18n/routing.ts` (forks may move
i18n). Pass `defaultLocale` and `locales` from the app.

**Every `generateMetadata` at page level must set `alternates.canonical` with
the absolute URL for that page.** Inheriting canonical from the layout alone is
incorrect for deep routes—the layout sets the root; each page must override with
its own path.

---

## Structured data (JSON-LD)

The marketing home page includes a minimal **Organization** script tag. Prefer
**inline** JSON-LD in the page that owns the entity (keeps the zero-barrel
policy and avoids stuffing schema into `packages/ui`). Use `buildJsonLd()` from
`@workspace/seo` for serialization.

Patterns and B2B/B2C notes: [structured-data.md](./structured-data.md).

---

## Viewport and theme color

`app/[locale]/layout.tsx` exports **`viewport`** and **`themeColor`** (Next.js
Metadata API). **`theme_color` in `manifest.ts` is not a substitute** for mobile
browser chrome—keep **`viewport.themeColor`** aligned with `manifest.ts`
`theme_color` at fork time.

---

## Web Vitals

`app/[locale]/_components/web-vitals.tsx` uses `useReportWebVitals`
(client-only, no SEO impact). FORK: wire to your analytics provider.

---

## Next.js config (example app)

`apps/example/next.config.mjs` sets **`compress: true`**,
**`poweredByHeader: false`**, and **`images.formats`** /
**`images.remotePatterns`** (empty until you use external `next/image` sources).
FORK: add `remotePatterns` before loading remote images.

---

## Canonical and multi-environment

- Locale layout metadata sets `alternates.canonical` and `alternates.languages`
  using `@workspace/seo` helpers; child pages must set **page-level** canonicals
  for their paths.
- **www vs apex:** choose one primary URL; enforce redirects at your host (CDN /
  `vercel.json` / DNS)—document the choice for your team.
- **Preview:** set `NEXT_PUBLIC_SITE_URL` to the **preview’s public https URL**
  if you need a successful production-mode build; keep `ROBOTS_ALLOW` **off** on
  preview. Details: [preview-environments.md](./preview-environments.md).

---

## i18n and hreflang (`next-intl`)

The example app uses **[next-intl](https://next-intl.dev)** with
**`defineRouting`** in `apps/example/i18n/routing.ts` (`locales`,
`defaultLocale`, `localePrefix`).

- **Middleware:** `apps/example/proxy.ts` runs `next-intl/middleware` **first**
  (locale detection, prefix redirects, **`Link` response header** for alternate
  URLs when enabled), then `@workspace/supabase-auth` `updateSession` so session
  cookies stay in sync without dropping i18n headers.
- **Metadata hreflang:** `app/[locale]/layout.tsx` sets `alternates.languages`
  to absolute URLs per locale. Align with sitemap `alternates.languages` when
  you add routes.
- **`localePrefix: 'as-needed'`:** the default locale is served without a path
  prefix (`/`); other locales use `/{locale}/...`. If you switch to `'always'`,
  update sitemap/robots patterns and Supabase redirect URLs accordingly.

Full fork guide: [i18n-lang.md](./i18n-lang.md).

---

## Measurement and CI (suggestions)

- **Lighthouse** SEO category locally:
  `npx lighthouse <url> --only-categories=seo`
- Optional **Lighthouse CI** in your pipeline—config is team-specific; start
  from [Google’s LHCI docs](https://github.com/GoogleChrome/lighthouse-ci).
- **Rich Results Test:**
  [search.google.com/test/rich-results](https://search.google.com/test/rich-results)

---

## Fork checklist (short)

Full list: [../checklists/seo-fork.md](../checklists/seo-fork.md).

App-specific overrides:
[../../apps/example/docs/seo.md](../../apps/example/docs/seo.md).

---

## Follow-up gaps (out of scope for the template defaults)

- **Per-page `opengraph-image.tsx`:** future content pages (blog, docs, pricing)
  should each have their own OG file with page-specific data. The template’s
  marketing home is the primary example.
- **Sitemap split / `generateSitemaps()`:** if a fork adds >50,000 URLs,
  implement `generateSitemaps()` with indexed sitemap files.
- **`lastModified` accuracy:** the sitemap currently uses `new Date()` (build
  time). Forks with CMS-backed content should use the actual content `updatedAt`
  timestamp.
- **Oxlint SEO rules:** `jsx-a11y` covers `alt` text enforcement. There is
  currently no lint rule that enforces `generateMetadata` on every new page
  file. Consider a custom oxlint rule or a CI check.
- **Social card testing:** add a CI step using `unfurl` or a similar tool to
  validate OG tag output on the deployed preview URL before merge.

---

## Related

- [preview-environments.md](./preview-environments.md) — Vercel preview,
  `ROBOTS_ALLOW`, `NEXT_PUBLIC_SITE_URL` on CI
- [i18n-lang.md](./i18n-lang.md) — `lang`, hreflang, content parity
- [structured-data.md](./structured-data.md) — JSON-LD types by use case
