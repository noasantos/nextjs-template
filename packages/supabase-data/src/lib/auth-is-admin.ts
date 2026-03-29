import type { TypedSupabaseClient } from "@workspace/supabase-infra/types/supabase"

/**
 * Matches Postgres `public.auth_is_admin()` (JWT and/or `user_roles`), same as RLS.
 */
async function getAuthIsAdmin(supabase: TypedSupabaseClient) {
  const { data, error } = await supabase.rpc("auth_is_admin")

  if (error) {
    return { ok: false as const, error }
  }

  return { ok: true as const, isAdmin: Boolean(data) }
}

export { getAuthIsAdmin }
