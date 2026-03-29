# SEO notes (`apps/example`)

How this app inherits **template SEO defaults** and where to override them when you fork.

---

## Inheriting template defaults

| File | Role |
|------|------|
| `app/layout.tsx` | Pass-through root layout only (no `<html>` / metadata). |
| `app/[locale]/layout.tsx` | `metadataBase`, default title template, Open Graph, Twitter, `alternates` (canonical + hreflang), `<html lang={locale}>`, fonts, providers + `NextIntlClientProvider` |
| `lib/site-url.ts` | `getSiteUrl()`, `getDefaultLocale()` (from `routing.defaultLocale`), `isRobotsAllowIndexing()` |
| `app/robots.ts` | Crawl rules gated by `ROBOTS_ALLOW`; locale-aware `disallow` patterns for auth paths |
| `app/sitemap.ts` | Public URLs per locale; empty when `ROBOTS_ALLOW` is not `true` |
| `app/manifest.ts` | PWA manifest stub |
| `app/[locale]/(auth)/layout.tsx`, `app/(auth-handlers)/layout.tsx` | `noindex,nofollow` for auth UI and auth HTTP handlers |
| `i18n/routing.ts` | Locales and `localePrefix` — source of truth with `messages/*.json` |

Canonical repo guide: [../../../docs/guides/seo.md](../../../docs/guides/seo.md).  
i18n details: [../../../docs/guides/i18n-lang.md](../../../docs/guides/i18n-lang.md).

---

## Page-level metadata

**Static page** under `app/[locale]/(marketing)/`:

```tsx
import type { Metadata } from "next"

export const metadata: Metadata = {
  title: "Pricing",
  description: "…",
}
```

**Dynamic metadata:** use `generateMetadata` — see `app/[locale]/layout.tsx` and `app/[locale]/(marketing)/page.tsx` for locale-aware `params`.

---

## JSON-LD on content pages

Add an inline script in the **same** Server Component that owns the content:

```tsx
const jsonLd = { "@context": "https://schema.org", "@type": "Article", /* … */ }
// …
;<script
  type="application/ld+json"
  dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
/>
```

Do not re-export schema builders from a barrel file; import helpers directly if you extract them (zero-barrel policy). See [../../../docs/guides/structured-data.md](../../../docs/guides/structured-data.md).

---

## What to change at fork time

- Replace placeholder strings in **`messages/en.json`** (and other locales) and **`app/manifest.ts`**.
- Set production **`NEXT_PUBLIC_SITE_URL`** (https) and **`ROBOTS_ALLOW=true`** only on the indexed deployment.
- Keep **`NEXT_PUBLIC_DEFAULT_LOCALE`** aligned with `i18n/routing.ts` `defaultLocale`.
- Swap **`/og-default.png`** for a branded 1200×630 asset.
- Extend **`sitemap.ts`** with your public routes; never list auth or admin URLs.
- Adjust **Organization** JSON-LD on the marketing home page (logo, `sameAs`, etc.).

Checklist: [../../../docs/checklists/seo-fork.md](../../../docs/checklists/seo-fork.md).
