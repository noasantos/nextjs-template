/**
 * **Baseline access template** — shared literals for DB + JWT tests.
 *
 * ### Roles (`public.app_roles` / `public.user_roles`)
 * Seed rows live in `supabase/seed.sql`. Replace `privilegedRole` with your operator
 * slug when the product does not use `admin`, then add a migration that updates
 * `auth_is_admin()` and any RLS policies that reference the old name.
 *
 * ### Permissions (JWT `app_metadata.permissions`)
 * The custom access token hook returns an **empty** `permissions` array from Postgres
 * until you model fine-grained codes. You can still put permission strings in JWT
 * metadata (or enrich the hook); client/server helpers parse them via
 * `getUserPermissionsFromClaims` and `requirePermission`. Canonical example code for
 * tests is `PERMISSIONS.exampleAccess` in `@workspace/supabase-auth/shared/permission`
 * — it must stay equal to `exampleJwtPermission` below.
 */
const ACCESS_CONTROL_TEMPLATE = {
  /** Example fine-grained code for `requirePermission` / claim parsing tests. */
  exampleJwtPermission: "app.example.access",
  /** Default member slug from seed (self-sign-up catalog row). */
  memberRole: "user",
  /** Default elevated slug from seed; RLS + `auth_is_admin()` target this name today. */
  privilegedRole: "admin",
} as const

export { ACCESS_CONTROL_TEMPLATE }
