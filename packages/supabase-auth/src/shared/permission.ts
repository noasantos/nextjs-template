/**
 * Template permission keys for JWT / `requirePermission`. Add codes here as you define them;
 * keep `exampleAccess` aligned with `ACCESS_CONTROL_TEMPLATE.exampleJwtPermission` in
 * `@workspace/supabase-auth/testing/access-control-template`.
 */
const PERMISSIONS = {
  exampleAccess: "app.example.access",
} as const

const AUTH_PERMISSIONS = Object.values(PERMISSIONS)

type Permission = (typeof AUTH_PERMISSIONS)[number]

function isPermission(value: string): value is Permission {
  return AUTH_PERMISSIONS.includes(value as Permission)
}

export { AUTH_PERMISSIONS, PERMISSIONS, isPermission, type Permission }
