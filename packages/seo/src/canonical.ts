function normalizePath(path: string): string {
  if (path === "/" || path === "") {
    return "/"
  }
  return path.startsWith("/") ? path : `/${path}`
}

/**
 * Returns the canonical absolute URL for a given locale and path.
 * Uses `as-needed` prefix strategy (default locale = no prefix).
 */
export function buildCanonicalUrl({
  siteUrl,
  locale,
  defaultLocale,
  path = "/",
}: {
  siteUrl: string
  locale: string
  defaultLocale: string
  path?: string
}): string {
  const origin = siteUrl.replace(/\/$/, "")
  const base = new URL(`${origin}/`)
  const normalized = normalizePath(path)

  const localePath =
    locale === defaultLocale ? normalized : `/${locale}${normalized === "/" ? "" : normalized}`

  return new URL(localePath, base).toString()
}
