type SupabasePublicEnv = {
  authAllowedRedirectOrigins: string[]
  authAppUrl: string
  authCookieDomain?: string
  supabasePublishableKey: string
  supabaseUrl: string
}

/**
 * Ensures values like `app.vercel.app` (missing scheme) parse as URLs.
 * Hosts without a scheme default to https; localhost-style hosts use http.
 */
function normalizePublicAppUrl(raw: string): string {
  const trimmed = raw.trim()
  if (!trimmed) {
    return trimmed
  }

  if (/^https?:\/\//i.test(trimmed)) {
    return trimmed
  }

  if (trimmed.startsWith("//")) {
    return `https:${trimmed}`
  }

  const hostish = trimmed.split("/")[0] ?? ""
  const lowerHost = hostish.toLowerCase()
  if (
    lowerHost.startsWith("localhost") ||
    lowerHost.startsWith("127.0.0.1") ||
    lowerHost.startsWith("0.0.0.0")
  ) {
    return `http://${trimmed}`
  }

  return `https://${trimmed}`
}

function getRequiredPublicEnv(
  name:
    | "NEXT_PUBLIC_AUTH_APP_URL"
    | "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"
    | "NEXT_PUBLIC_SUPABASE_URL"
) {
  const value = (() => {
    switch (name) {
      case "NEXT_PUBLIC_AUTH_APP_URL":
        return process.env.NEXT_PUBLIC_AUTH_APP_URL
      case "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY":
        return process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
      case "NEXT_PUBLIC_SUPABASE_URL":
        return process.env.NEXT_PUBLIC_SUPABASE_URL
    }
  })()

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`)
  }

  return value
}

function getOptionalPublicEnv(
  name:
    | "NEXT_PUBLIC_AUTH_ALLOWED_REDIRECT_ORIGINS"
    | "NEXT_PUBLIC_AUTH_COOKIE_DOMAIN"
) {
  const value =
    name === "NEXT_PUBLIC_AUTH_ALLOWED_REDIRECT_ORIGINS"
      ? process.env.NEXT_PUBLIC_AUTH_ALLOWED_REDIRECT_ORIGINS
      : process.env.NEXT_PUBLIC_AUTH_COOKIE_DOMAIN

  return value?.trim() || undefined
}

function getSupabasePublishableKey() {
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.trim()
  if (!key) {
    throw new Error(
      "Missing required environment variable: NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"
    )
  }
  return key
}

function getSupabasePublicEnv(): SupabasePublicEnv {
  const authAppUrl = normalizePublicAppUrl(
    getRequiredPublicEnv("NEXT_PUBLIC_AUTH_APP_URL")
  )
  const authAllowedRedirectOrigins = new Set([
    new URL(authAppUrl).origin,
    ...(getOptionalPublicEnv("NEXT_PUBLIC_AUTH_ALLOWED_REDIRECT_ORIGINS")
      ?.split(",")
      .map((value) => value.trim())
      .filter(Boolean) ?? []),
  ])

  return {
    authAllowedRedirectOrigins: Array.from(authAllowedRedirectOrigins),
    authAppUrl,
    authCookieDomain: getOptionalPublicEnv("NEXT_PUBLIC_AUTH_COOKIE_DOMAIN"),
    supabasePublishableKey: getSupabasePublishableKey(),
    supabaseUrl: getRequiredPublicEnv("NEXT_PUBLIC_SUPABASE_URL"),
  }
}

export { getSupabasePublicEnv, normalizePublicAppUrl, type SupabasePublicEnv }
