import type { UserResponse } from "@supabase/supabase-js"

import { createBrowserAuthClient } from "@workspace/supabase-auth/browser/create-browser-auth-client"

type UpdatePasswordInput = {
  password: string
}

async function updatePassword({ password }: UpdatePasswordInput): Promise<UserResponse> {
  const supabase = createBrowserAuthClient()

  return supabase.auth.updateUser({ password })
}

export { updatePassword, type UpdatePasswordInput }
