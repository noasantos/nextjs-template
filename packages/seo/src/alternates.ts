function normalizePath(path: string): string {
  if (path === "/" || path === "") {
    return "/"
  }
  return path.startsWith("/") ? path : `/${path}`
}

/**
 * Builds the `alternates.languages` map for Next.js Metadata API.
 * Compatible with next-intl `as-needed` prefix strategy.
 */
export function buildAlternateLanguages({
  siteUrl,
  locales,
  defaultLocale,
  path = "/",
}: {
  siteUrl: string
  locales: readonly string[]
  defaultLocale: string
  path?: string
}): Record<string, string> {
  const origin = siteUrl.replace(/\/$/, "")
  const base = new URL(`${origin}/`)
  const normalized = normalizePath(path)

  return Object.fromEntries(
    locales.map((l) => {
      const localePath =
        l === defaultLocale ? normalized : `/${l}${normalized === "/" ? "" : normalized}`
      return [l, new URL(localePath, base).toString()]
    })
  )
}
