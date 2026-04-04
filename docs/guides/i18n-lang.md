# Internationalization (i18n) and languages

Template guide for **forkers** using the `apps/example` **next-intl** setup.

---

## Where configuration lives

| Piece                                          | Path                                                                                    |
| ---------------------------------------------- | --------------------------------------------------------------------------------------- |
| Locales, default locale, `localePrefix`        | `apps/example/i18n/routing.ts` (`defineRouting`)                                        |
| Per-request messages                           | `apps/example/i18n/request.ts` (`getRequestConfig`)                                     |
| `Link`, `redirect`, `useRouter`, `usePathname` | `apps/example/i18n/navigation.ts` (`createNavigation`)                                  |
| Message JSON                                   | `apps/example/messages/{locale}.json`                                                   |
| Locale segment + `<html lang>`                 | `apps/example/app/[locale]/layout.tsx`                                                  |
| Proxy (ingress)                                | `apps/example/proxy.ts` — **next-intl middleware first**, then Supabase `updateSession` |

Optional future step for **multiple Next apps**: extract shared routing +
messages into `packages/i18n` (see comment in `routing.ts`).

---

## Adding a locale

1. Add the locale to `routing.locales` in `apps/example/i18n/routing.ts`.
2. Add `messages/<locale>.json` (copy `en.json` as a skeleton).
3. Regenerate or extend `generateStaticParams` if you customize static
   generation.
4. Update **Supabase** and **auth** allowed redirect URLs if you use
   locale-prefixed paths for auth UI (`/pt/sign-in`, etc.).
5. Re-check `app/sitemap.ts` and `app/robots.ts` (template already loops
   `routing.locales`).

---

## hreflang and SEO

- **Response header:** `next-intl` middleware can emit a `Link` header with
  alternate URLs (depends on routing config / version). **`updateSession`**
  preserves `Link` and `x-next-intl-*` headers when composing with the Supabase
  proxy.
- **HTML metadata:** `app/[locale]/layout.tsx` sets `alternates.languages` with
  absolute URLs. Keep **sitemap** `alternates.languages` consistent when you add
  marketing routes.

Do **not** add `hreflang` for locales that are not **fully** public or lack
content parity—search engines treat mismatches as low quality.

---

## B2B vs B2C

- **B2B:** Few locales (often one). Prefer `localePrefix: 'as-needed'` for a
  clean default market URL.
- **B2C:** More locales; consider `localePrefix: 'always'` for clearer
  multi-market URLs, or domain-based routing for large deployments. See comments
  in `routing.ts`.

---

## Content parity

Before shipping a new locale, ensure **≥ ~80%** of user-facing strings exist in
that locale’s JSON (and in auth flows you expose). Missing keys fall back per
`next-intl` rules; empty sections hurt UX.

---

## Related

- [seo.md](./seo.md) — metadataBase, robots, sitemap, checklist links
- [apps/example/messages/AGENTS.md](../../apps/example/messages/AGENTS.md) —
  message file structure
- [next-intl routing docs](https://next-intl.dev/docs/routing)
