# Structured data (JSON-LD)

Patterns for **schema.org** markup in forks. Keep JSON-LD **next to the page** that represents the entity (inline `<script type="application/ld+json">` or a small colocated component in `apps/<app>/`)—do not put product schema inside `packages/ui` (immutable shadcn vendor tree); shared **non-UI** helpers may live in `packages/brand` or app `lib/` if needed.

---

## Organization (B2B / brand)

Use for company / product identity on the homepage or About page.

- **Fields:** `@context`, `@type: Organization`, `name`, `url`, optional `logo`, `sameAs` (social profiles).
- **Example** stub: `apps/example/app/(marketing)/page.tsx`.

---

## WebSite + SearchAction (B2C / search-heavy)

For sites with a **public search** results page, **WebSite** with `potentialAction` of type **SearchAction** can enable a sitelinks search box in some cases.

- Only add if you have a real search URL template and stable query parameter.
- Validate with [Rich Results Test](https://search.google.com/test/rich-results).

---

## Article / BlogPosting

For blog posts or changelog entries:

- Use **`BlogPosting`** or **`Article`** with `headline`, `datePublished`, `author`, `image`, `mainEntityOfPage`.
- Prefer **`generateMetadata`** for title/description alignment with JSON-LD.

---

## Product and Review (B2C commerce)

- **Product** — `name`, `image`, `description`, `offers` (price, currency, availability).
- **Review** / **AggregateRating** — only if you have **real**, crawlable review content; avoid misleading ratings.

---

## BreadcrumbList

Use on nested marketing or content pages to reflect hierarchy in SERPs when appropriate.

---

## B2B vs B2C summary

| Use case | Common types |
|----------|----------------|
| B2B marketing | **Organization**, optional **WebSite** |
| Blog / content | **Article** / **BlogPosting**, **BreadcrumbList** |
| B2C storefront | **Product**, **Offer**, **Review** (with compliance) |
| Large site + on-site search | **WebSite** + **SearchAction** |

---

## Related

- [seo.md](./seo.md) — metadata, sitemap, robots
- [i18n-lang.md](./i18n-lang.md) — locale and `hreflang`
