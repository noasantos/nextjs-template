import "server-only"
import { redirect } from "next/navigation"

import { getRequestUrl } from "@workspace/supabase-auth/server/get-request-url"
import { getAccess } from "@workspace/supabase-auth/session/get-access"
import { getClaims } from "@workspace/supabase-auth/session/get-claims"
import {
  buildAuthAccessDeniedUrl,
  buildAuthSignInUrl,
} from "@workspace/supabase-auth/shared/auth-redirect"
import type { Permission } from "@workspace/supabase-auth/shared/permission"

type RequirePermissionOptions = {
  permission: Permission
  redirectTo?: string
}

async function requirePermission({
  permission,
  redirectTo,
}: RequirePermissionOptions): Promise<void> {
  const claims = await getClaims()
  const safeRedirectTo = redirectTo ?? (await getRequestUrl()) ?? undefined

  if (!claims?.sub) {
    redirect(buildAuthSignInUrl(safeRedirectTo))
  }

  const { permissions } = await getAccess(claims)

  if (permissions.includes(permission)) {
    return
  }

  redirect(buildAuthAccessDeniedUrl(safeRedirectTo, [permission]))
}

export { requirePermission, type RequirePermissionOptions }
