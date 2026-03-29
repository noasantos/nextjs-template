# Preview and staging environments

How **SEO-related env vars** interact with Vercel previews, staging, and production for `apps/example`.

---

## robots.ts environment guard

`ROBOTS_ALLOW` is read in `apps/example/app/robots.ts` and `app/sitemap.ts`:

- **`ROBOTS_ALLOW=true`** — allow `/` in `robots.txt` and emit sitemap entries.
- **Anything else** — `Disallow: /` and an **empty** sitemap array so preview/staging URLs are not accidentally submitted to Search Console.

Set `ROBOTS_ALLOW=true` **only** on the production deployment that should be indexed.

---

## Vercel preview URL strategy

**Production builds** (`next build`, `NODE_ENV=production`) require `NEXT_PUBLIC_SITE_URL` to be **https** with a **non-local** hostname (`apps/example/next.config.mjs`).

For **preview** deployments:

1. Set `NEXT_PUBLIC_SITE_URL` to the preview’s public URL (e.g. `https://<project>-git-<branch>-<team>.vercel.app` or your custom preview domain). You can use Vercel’s **environment variable** UI: set `NEXT_PUBLIC_SITE_URL` for *Preview* to `$VERCEL_URL` with `https://` prefix if your provider supports composition, or maintain a pattern per project.
2. Keep **`ROBOTS_ALLOW` unset or `false`** for Preview and Development environments so crawlers are blocked.
3. Result: build passes, OG tags resolve to absolute preview URLs, but search engines should not index the deployment.

---

## Canonical in CI

If CI runs `next build` with production mode:

- Inject a valid **`NEXT_PUBLIC_SITE_URL`** (staging canonical or production—match the environment you are validating).
- Do **not** set `ROBOTS_ALLOW=true` on staging unless that environment is intended to be indexed.

---

## Search Console property scoping

- **One Search Console property per origin** you care about (e.g. `https://example.com` vs `https://www.example.com` vs a separate marketing app on another subdomain).
- **Multi-app monorepo:** if `apps/landing` and `apps/example` deploy to **different** origins, use **separate** properties (or domain-level property with path understanding where appropriate). Do not mix sitemaps across origins.

**Domain vs URL-prefix property:** domain properties cover all subdomains and protocols; URL-prefix is limited to one exact base URL. Pick based on how many hosts you need in one report.

---

## Related

- [seo.md](./seo.md) — full SEO guide
- [../checklists/seo-fork.md](../checklists/seo-fork.md) — pre-launch checklist
