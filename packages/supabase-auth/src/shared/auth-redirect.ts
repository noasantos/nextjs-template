import type { EmailOtpType } from "@supabase/supabase-js"

import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"

const LOGIN_PATH = "/sign-in" as const
const DEFAULT_AUTH_APP_PATH = LOGIN_PATH
const ACCESS_DENIED_PATH = "/access-denied" as const
const CALLBACK_PATH = "/callback" as const
const CONFIRM_PATH = "/auth/confirm" as const
const CONTINUE_PATH = "/continue" as const
const RESET_PASSWORD_PATH = "/reset-password" as const
const LOGOUT_PATH = "/logout" as const

function getAuthAppOrigin() {
  return new URL(getSupabasePublicEnv().authAppUrl).origin
}

function getDefaultRedirectTo() {
  return new URL(
    DEFAULT_AUTH_APP_PATH,
    getSupabasePublicEnv().authAppUrl
  ).toString()
}

function isSafeRedirectTo(value: string | null | undefined) {
  if (!value) {
    return false
  }

  let redirectUrl: URL

  try {
    redirectUrl = new URL(value)
  } catch {
    return false
  }

  const { authAllowedRedirectOrigins } = getSupabasePublicEnv()

  return authAllowedRedirectOrigins.includes(redirectUrl.origin)
}

function getSafeRedirectTo(
  value: string | null | undefined,
  fallback = getDefaultRedirectTo()
) {
  if (!value) {
    return fallback
  }

  return isSafeRedirectTo(value) ? value : fallback
}

function buildAuthUrl(
  pathname: string,
  searchParams?: Record<string, string | null | undefined | readonly string[]>
) {
  const url = new URL(pathname, getSupabasePublicEnv().authAppUrl)

  Object.entries(searchParams ?? {}).forEach(([key, rawValue]) => {
    if (!rawValue) {
      return
    }

    if (Array.isArray(rawValue)) {
      rawValue.forEach((value) => {
        if (value) {
          url.searchParams.append(key, value)
        }
      })

      return
    }

    url.searchParams.set(key, String(rawValue))
  })

  return url.toString()
}

function buildAuthCallbackUrl(redirectTo?: string | null) {
  return buildAuthUrl(CALLBACK_PATH, {
    redirect_to: getSafeRedirectTo(redirectTo),
  })
}

function buildAuthContinueUrl(redirectTo?: string | null) {
  return buildAuthUrl(CONTINUE_PATH, {
    redirect_to: getSafeRedirectTo(redirectTo),
  })
}

function buildAuthConfirmUrl(type: EmailOtpType, redirectTo?: string | null) {
  return buildAuthUrl(CONFIRM_PATH, {
    redirect_to: getSafeRedirectTo(redirectTo),
    type,
  })
}

function buildAuthResetPasswordUrl(redirectTo?: string | null) {
  return buildAuthUrl(RESET_PASSWORD_PATH, {
    redirect_to: getSafeRedirectTo(redirectTo),
  })
}

function buildAuthSignInUrl(redirectTo?: string | null) {
  return buildAuthUrl(LOGIN_PATH, {
    redirect_to: getSafeRedirectTo(redirectTo),
  })
}

function buildAuthAccessDeniedUrl(
  redirectTo?: string | null,
  requiredRoles?: readonly string[]
) {
  return buildAuthUrl(ACCESS_DENIED_PATH, {
    redirect_to: getSafeRedirectTo(redirectTo),
    required: requiredRoles?.join(","),
  })
}

function buildAuthLogoutUrl(redirectTo?: string | null) {
  return buildAuthUrl(LOGOUT_PATH, {
    redirect_to: getSafeRedirectTo(redirectTo, buildAuthUrl(LOGIN_PATH)),
  })
}

export {
  buildAuthAccessDeniedUrl,
  buildAuthCallbackUrl,
  buildAuthContinueUrl,
  buildAuthConfirmUrl,
  buildAuthLogoutUrl,
  buildAuthResetPasswordUrl,
  buildAuthSignInUrl,
  getAuthAppOrigin,
  getDefaultRedirectTo,
  getSafeRedirectTo,
  isSafeRedirectTo,
}
