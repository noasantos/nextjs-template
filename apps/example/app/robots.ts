import type { MetadataRoute } from "next"

import { getSiteUrl, isRobotsAllowIndexing } from "@/lib/site-url"

const authAdminDisallow = [
  "/sign-in",
  "/logout",
  "/callback",
  "/forgot-password",
  "/reset-password",
  "/magic-link",
  "/mfa",
  "/access-denied",
  "/continue",
  "/auth/",
  "/*/sign-in",
  "/*/logout",
  "/*/callback",
  "/*/forgot-password",
  "/*/reset-password",
  "/*/magic-link",
  "/*/mfa",
  "/*/access-denied",
  "/*/continue",
  "/*/auth/",
]

export default function robots(): MetadataRoute.Robots {
  const base = getSiteUrl()
  const origin = new URL(`${base}/`)

  if (!isRobotsAllowIndexing()) {
    return {
      rules: {
        userAgent: "*",
        disallow: "/",
      },
    }
  }

  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: authAdminDisallow,
    },
    sitemap: new URL("/sitemap.xml", origin).toString(),
    host: origin.host,
  }
}
