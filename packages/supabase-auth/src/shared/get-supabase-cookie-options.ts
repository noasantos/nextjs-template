import type { CookieOptionsWithName } from "@supabase/ssr"

import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"

function getSupabaseCookieOptions(): CookieOptionsWithName {
  const { authAppUrl, authCookieDomain } = getSupabasePublicEnv()
  const authOrigin = new URL(authAppUrl)

  return {
    domain: authCookieDomain,
    path: "/",
    sameSite: "lax",
    secure: authOrigin.protocol === "https:",
  }
}

export { getSupabaseCookieOptions }
