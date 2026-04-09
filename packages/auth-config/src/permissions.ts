/**
 * JWT permission codes for this workspace.
 *
 * Each key is a logical name used in `requirePermission()`; each value is
 * the permission string that must appear in the JWT `permissions` claim.
 *
 * When adopting this template for a different product, replace these entries
 * with the permissions relevant to that product.
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
