import { createSafeActionClient } from "next-safe-action"

import { getClaims } from "@workspace/supabase-auth/session/get-claims"

// Base action client
export const actionClient = createSafeActionClient()

// Auth action client with middleware
export const authActionClient = actionClient.use(async ({ next, ctx: _ctx }) => {
  const claims = await getClaims()

  if (!claims?.sub) {
    throw new Error("Unauthorized")
  }

  return next({ ctx: { userId: claims.sub } })
})
