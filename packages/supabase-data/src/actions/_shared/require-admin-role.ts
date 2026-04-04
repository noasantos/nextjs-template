import type { JwtPayload } from "@supabase/supabase-js"

import { getAuthIsAdmin } from "@workspace/supabase-data/lib/auth-is-admin"
import type { TypedSupabaseClient } from "@workspace/supabase-infra/types"

async function requireAdminRole(claims: JwtPayload | null, supabase: TypedSupabaseClient) {
  if (!claims?.sub) {
    return { ok: false as const, reason: "missing_claims" as const }
  }

  const admin = await getAuthIsAdmin(supabase)
  if (!admin.ok) {
    return {
      ok: false as const,
      reason: "auth_check_failed" as const,
      userId: claims.sub,
    }
  }

  if (!admin.isAdmin) {
    return {
      ok: false as const,
      reason: "not_admin" as const,
      userId: claims.sub,
    }
  }

  return { ok: true as const, userId: claims.sub }
}

export { requireAdminRole }
