import { routing } from "@/i18n/routing"

const LOCAL_FALLBACK = "http://localhost:3000"

/**
 * Canonical origin for metadataBase, sitemap, robots host, and JSON-LD.
 * Prefer `NEXT_PUBLIC_SITE_URL`; fall back to auth app origin in dev.
 */
export function getSiteUrl(): string {
  const fromSite = process.env.NEXT_PUBLIC_SITE_URL?.trim()
  const fromAuth = process.env.NEXT_PUBLIC_AUTH_APP_URL?.trim()
  const raw = fromSite || fromAuth || LOCAL_FALLBACK
  return raw.replace(/\/+$/, "")
}

/** Source of truth: `routing.defaultLocale` in `i18n/routing.ts`. Keep `NEXT_PUBLIC_DEFAULT_LOCALE` aligned when you fork. */
export function getDefaultLocale(): string {
  return routing.defaultLocale
}

/** When false/unset, robots disallow all and sitemap is empty (preview/staging/local). */
export function isRobotsAllowIndexing(): boolean {
  return process.env.ROBOTS_ALLOW === "true"
}
