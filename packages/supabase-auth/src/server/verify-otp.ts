import "server-only"

import type { AuthResponse, EmailOtpType } from "@supabase/supabase-js"

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"

type VerifyOtpInput = {
  tokenHash: string
  type: EmailOtpType
}

async function verifyOtp({
  tokenHash,
  type,
}: VerifyOtpInput): Promise<AuthResponse> {
  const supabase = await createServerAuthClient()

  return supabase.auth.verifyOtp({
    token_hash: tokenHash,
    type,
  })
}

export { verifyOtp, type VerifyOtpInput }
