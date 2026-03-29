import type { MetadataRoute } from "next"

import { routing } from "@/i18n/routing"
import { getSiteUrl, isRobotsAllowIndexing } from "@/lib/site-url"

const publicRoutes = ["/"]

/**
 * Public marketing URLs only, per locale (`localePrefix: as-needed` — default locale has no prefix).
 * When `ROBOTS_ALLOW` is not `true`, returns [] (preview/staging).
 */
export default function sitemap(): MetadataRoute.Sitemap {
  if (!isRobotsAllowIndexing()) {
    return []
  }

  const base = getSiteUrl()
  const origin = new URL(`${base}/`)
  const now = new Date()
  const entries: MetadataRoute.Sitemap = []

  for (const route of publicRoutes) {
    for (const locale of routing.locales) {
      const isDefault = locale === routing.defaultLocale
      const localePath = isDefault
        ? route
        : `/${locale}${route === "/" ? "" : route}`
      const url = new URL(localePath || "/", origin).toString()

      const languageAlternates = Object.fromEntries(
        routing.locales.map((l) => {
          const path =
            l === routing.defaultLocale
              ? route
              : `/${l}${route === "/" ? "" : route}`
          return [l, new URL(path || "/", origin).toString()]
        })
      )

      entries.push({
        url,
        lastModified: now,
        changeFrequency: route === "/" ? "weekly" : "monthly",
        priority: route === "/" ? 1 : 0.8,
        alternates: { languages: languageAlternates },
      })
    }
  }

  return entries
}
