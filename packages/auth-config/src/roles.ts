/**
 * Application role definitions for this workspace.
 *
 * This file owns the concrete role vocabulary consumed by `@workspace/supabase-auth`.
 * When adopting this template for a different product, replace the role names,
 * labels, and alias map here — do not edit `@workspace/supabase-auth` directly.
 */

const AUTH_ROLES = ["admin", "patient", "psychologist"] as const

type AuthRole = (typeof AUTH_ROLES)[number]

const AUTH_ROLE_LABELS: Record<AuthRole, string> = {
  admin: "Admin",
  patient: "Patient",
  psychologist: "Psychologist",
}

/**
 * Legacy DB / JWT slug aliases that should be normalised to a canonical role.
 * Keys are raw values that may appear in JWT claims; values are the canonical `AuthRole`.
 *
 * Remove or replace when the underlying DB schema no longer emits legacy slugs.
 */
const AUTH_ROLE_ALIASES: Record<string, AuthRole> = {
  user: "patient",
  psychotherapist: "psychologist",
}

/**
 * The role that is granted full access to every surface when present in the JWT.
 * Must be a member of `AUTH_ROLES`.
 */
const AUTH_PRIVILEGED_ROLE = "admin" satisfies AuthRole

export { AUTH_ROLE_ALIASES, AUTH_ROLE_LABELS, AUTH_ROLES, AUTH_PRIVILEGED_ROLE, type AuthRole }
