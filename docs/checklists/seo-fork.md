# SEO fork checklist

Quick reference before **first production** deploy of a fork. Canonical
narrative: [../guides/seo.md](../guides/seo.md).

---

## Pre-launch — code

- [ ] `NEXT_PUBLIC_SITE_URL` is **https** with a **public** hostname in
      production (local `http://localhost` is dev-only; `next build` enforces
      https + public host when `NODE_ENV=production`).
- [ ] `NEXT_PUBLIC_AUTH_APP_URL` matches the app that serves `/sign-in` and
      callbacks (may equal `SITE_URL` for single-origin apps).
- [ ] `NEXT_PUBLIC_DEFAULT_LOCALE` matches `defaultLocale` in
      `apps/example/i18n/routing.ts` (actual `<html lang>` comes from the URL
      `[locale]` segment).
- [ ] `ROBOTS_ALLOW=true` **only** on the deployment you want indexed; **false**
      or unset on preview/staging.
- [ ] Replaced placeholder **title**, **description**, **OG image**
      (`apps/example/public/og-default.png` or your asset), and **manifest**
      name/theme in `messages/*.json`, `app/[locale]/layout.tsx`, and
      `app/manifest.ts`.
- [ ] **`lib/public-routes.ts`** lists every indexable path; `app/sitemap.ts`
      derives entries from it. Confirmed only **public** URLs (no `/sign-in`,
      password reset, etc.) and **hreflang** `alternates.languages` match live
      locales.
- [ ] **i18n:** every shipped locale has a `messages/<locale>.json`;
      `routing.locales` matches product scope; internal links use
      `@/i18n/navigation` `Link` where locale must be preserved.
- [ ] Each public `apps/*` Next app has its **own** `robots.ts` and `sitemap.ts`
      if it is a separate origin or product.

---

## Pre-launch — content

- [ ] Unique **title** and **meta description** per important page; no lorem
      ipsum live.
- [ ] One clear **h1** per page on marketing content.
- [ ] Internal links do not point to **404** routes (admin/marketing parity).

---

## Pre-launch — technical

- [ ] Production build succeeds with your real `NEXT_PUBLIC_SITE_URL`.
- [ ] View source or DevTools: **canonical** `<link rel="canonical">` points at
      your production origin (not localhost).
- [ ] `/robots.txt` allows crawling only when intended; **disallows all** when
      `ROBOTS_ALLOW` is not `true`.
- [ ] `/sitemap.xml` is empty or omitted from submission when indexing is
      disabled; when enabled, contains no auth URLs.
- [ ] Lighthouse **SEO** ≥ 90 on `/` (target; fix regressions before launch).

---

## Manual verification (tools)

- [ ] [Google Rich Results Test](https://search.google.com/test/rich-results) —
      homepage; Organization JSON-LD if used.
- [ ] [OpenGraph.xyz](https://www.opengraph.xyz) or network preview — OG title,
      description, image.
- [ ] [Twitter/X card preview](https://cards-dev.twitter.com/validator) (if
      still available) or post-preview in the target platform —
      `summary_large_image`.

---

## Post-launch

- [ ] **Google Search Console**: add property (domain or URL prefix), submit
      sitemap, monitor coverage.
- [ ] Within ~48h: confirm auth/admin URLs are not indexed (use `site:` queries
      and GSC).

---

## Agents

When scaffolding a new public app from this template, read
[../guides/seo.md](../guides/seo.md) and mirror the `apps/example` patterns for
`metadataBase`, `robots.ts`, and `sitemap.ts`.
