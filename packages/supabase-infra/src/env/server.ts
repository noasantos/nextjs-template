import "server-only"

import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import { resolveServiceRoleKeyWhenUnset } from "@workspace/supabase-infra/env/resolve-service-role-key"

type SupabaseServerEnv = ReturnType<typeof getSupabasePublicEnv> & {
  serviceRoleKey: string
}

function getSupabaseServerEnv(): SupabaseServerEnv {
  return {
    ...getSupabasePublicEnv(),
    serviceRoleKey: resolveServiceRoleKeyWhenUnset(),
  }
}

export { getSupabaseServerEnv, type SupabaseServerEnv }
