import type { JwtPayload } from "@supabase/supabase-js"

import { normalizePublicAppUrl } from "@workspace/supabase-infra/env/public"

import { AUTH_ROLE_LABELS } from "@workspace/supabase-auth/shared/auth-role"
import { getUserRolesFromClaims } from "@workspace/supabase-auth/shared/get-user-roles-from-claims"
import {
  buildAuthAccessDeniedUrl,
  buildAuthSignInUrl,
  getAuthAppOrigin,
  getSafeRedirectTo,
} from "@workspace/supabase-auth/shared/auth-redirect"
import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"

/**
 * URL segments for the primary Next.js app (same origin as auth).
 * Marketing/landing lives at `/` (route group `(marketing)`).
 * Add more keys here when the fork introduces role-specific surfaces (e.g. `/admin`).
 * @see apps/example
 */
const APP_SEGMENT_PATHS = {
  institutional: "/",
} as const

type AppSegmentKey = keyof typeof APP_SEGMENT_PATHS

/**
 * Where each role lands after sign-in.
 */
const ROLE_APP_MAP: Record<AuthRole, AppSegmentKey> = {
  admin: "institutional",
  user: "institutional",
}

const AUTH_LOGIN_PATH = "/sign-in" as const
const AUTH_ROUTE_PREFIXES = [
  "/access-denied",
  "/auth/confirm",
  "/callback",
  "/continue",
  "/forgot-password",
  AUTH_LOGIN_PATH,
  "/logout",
  "/magic-link",
  "/mfa",
  "/reset-password",
] as const

type AppSurfaceKey = AppSegmentKey | "auth"
type AppDestination = {
  app: AppSurfaceKey
  href: string
  label: string
  role: AuthRole | null
}
type ContinueDecision =
  | { kind: "redirect"; href: string }
  | { kind: "chooser"; destinations: AppDestination[] }
  | { kind: "access-denied"; href: string }

const APP_SEGMENT_KEYS = Object.keys(APP_SEGMENT_PATHS) as AppSegmentKey[]

/** Primary app origin: aligns with `NEXT_PUBLIC_AUTH_APP_URL` (single-app template). */
function getPrimaryAppOrigin(): string {
  const auth = process.env.NEXT_PUBLIC_AUTH_APP_URL?.trim()
  if (auth) {
    return new URL(normalizePublicAppUrl(auth)).origin
  }
  return "http://localhost:3000"
}

function getConfiguredAppUrl(app: AppSurfaceKey): string {
  if (app === "auth") {
    return new URL(AUTH_LOGIN_PATH, getPrimaryAppOrigin()).toString()
  }

  const path = APP_SEGMENT_PATHS[app]
  return new URL(path, getPrimaryAppOrigin()).toString()
}

/**
 * True when the URL is the shared auth landing (`/sign-in`) — no concrete workspace yet.
 * In that case we route by role to the default app surface instead of looping on `/sign-in`.
 */
function isAuthAppLandingOrSignIn(value: string): boolean {
  try {
    const u = new URL(value)
    const authOrigin = getPrimaryAppOrigin()
    if (u.origin !== authOrigin) {
      return false
    }
    return u.pathname === AUTH_LOGIN_PATH
  } catch {
    return false
  }
}

function isAuthRoutePath(pathname: string): boolean {
  return AUTH_ROUTE_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`)
  )
}

function getAppKeyForUrl(value: string): AppSurfaceKey | null {
  const redirectUrl = new URL(value)
  const primaryOrigin = getPrimaryAppOrigin()

  if (redirectUrl.origin === primaryOrigin) {
    if (isAuthRoutePath(redirectUrl.pathname)) {
      return "auth"
    }

    const sorted = [...APP_SEGMENT_KEYS].sort(
      (a, b) => APP_SEGMENT_PATHS[b].length - APP_SEGMENT_PATHS[a].length
    )
    for (const key of sorted) {
      const prefix = APP_SEGMENT_PATHS[key]
      if (
        redirectUrl.pathname === prefix ||
        redirectUrl.pathname.startsWith(`${prefix}/`)
      ) {
        return key
      }
    }
  }

  return null
}

function getDefaultAppForRoles(roles: readonly AuthRole[]) {
  for (const role of roles) {
    return getConfiguredAppUrl(ROLE_APP_MAP[role])
  }

  return null
}

function getDestinationsForRoles(roles: readonly AuthRole[]): AppDestination[] {
  return roles
    .map((role) => ({
      app: ROLE_APP_MAP[role],
      href: getConfiguredAppUrl(ROLE_APP_MAP[role]),
      label: AUTH_ROLE_LABELS[role],
      role,
    }))
    .filter(
      (destination, index, destinations) =>
        destinations.findIndex(
          (candidate) => candidate.role === destination.role
        ) === index
    )
}

function buildAuthContinueUrl(redirectTo?: string | null) {
  const url = new URL("/continue", getAuthAppOrigin())

  url.searchParams.set("redirect_to", getSafeRedirectTo(redirectTo))

  return url.toString()
}

function resolveAuthorizedRedirect({
  claims,
  redirectTo,
}: {
  claims: JwtPayload
  redirectTo?: string | null
}) {
  const requestedRedirectTo = getSafeRedirectTo(redirectTo)
  const requestedApp = getAppKeyForUrl(requestedRedirectTo)
  const roles = getUserRolesFromClaims(claims)

  if (requestedApp === "institutional") {
    return requestedRedirectTo
  }

  if (
    requestedApp === "auth" &&
    isAuthAppLandingOrSignIn(requestedRedirectTo)
  ) {
    return getDefaultAppForRoles(roles) ?? getConfiguredAppUrl("institutional")
  }

  if (!requestedApp) {
    return requestedRedirectTo
  }

  if (requestedApp === "auth") {
    return requestedRedirectTo
  }

  if (roles.includes(requestedApp as AuthRole)) {
    return requestedRedirectTo
  }

  return (
    getDefaultAppForRoles(roles) ??
    buildAuthAccessDeniedUrl(requestedRedirectTo, [requestedApp]) ??
    buildAuthSignInUrl(requestedRedirectTo)
  )
}

function getContinueDecision({
  redirectTo,
  roles,
}: {
  redirectTo?: string | null
  roles: readonly AuthRole[]
}): ContinueDecision {
  const requestedRedirectTo = getSafeRedirectTo(redirectTo)
  const requestedApp = getAppKeyForUrl(requestedRedirectTo)

  if (requestedApp === "institutional") {
    return { kind: "redirect", href: requestedRedirectTo }
  }

  if (
    requestedApp === "auth" &&
    isAuthAppLandingOrSignIn(requestedRedirectTo)
  ) {
    if (roles.length === 1 && roles[0]) {
      return {
        kind: "redirect",
        href: getConfiguredAppUrl(ROLE_APP_MAP[roles[0]]),
      }
    }
    if (roles.length > 1) {
      return { kind: "chooser", destinations: getDestinationsForRoles(roles) }
    }
    return {
      kind: "redirect",
      href: getConfiguredAppUrl("institutional"),
    }
  }

  if (!requestedApp) {
    return { kind: "redirect", href: requestedRedirectTo }
  }

  if (requestedApp === "auth") {
    return { kind: "redirect", href: requestedRedirectTo }
  }

  if (roles.includes(requestedApp as AuthRole)) {
    return { kind: "redirect", href: requestedRedirectTo }
  }

  if (roles.length === 1) {
    const [singleRole] = roles

    if (singleRole) {
      return {
        kind: "redirect",
        href: getConfiguredAppUrl(ROLE_APP_MAP[singleRole]),
      }
    }
  }

  if (roles.length > 1) {
    return { kind: "chooser", destinations: getDestinationsForRoles(roles) }
  }

  return {
    kind: "access-denied",
    href: buildAuthAccessDeniedUrl(requestedRedirectTo, [requestedApp]),
  }
}

export {
  buildAuthContinueUrl,
  getContinueDecision,
  getConfiguredAppUrl,
  getDestinationsForRoles,
  resolveAuthorizedRedirect,
  type AppDestination,
  type ContinueDecision,
  type AppSurfaceKey,
}
