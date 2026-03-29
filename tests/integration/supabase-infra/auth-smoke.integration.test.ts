import { describe, expect, it } from "vitest"

import { createAdminClient } from "@workspace/supabase-infra/clients/create-admin-client"
import { signInAsTestUser } from "@workspace/test-utils/supabase/users"

describe("local Supabase auth smoke", () => {
  it("creates a test user and signs in through the anon client", async () => {
    const { client, user } = await signInAsTestUser()
    const { data, error } = await client.auth.getUser()

    expect(error).toBeNull()
    expect(data.user?.id).toBe(user.userId)
    expect(data.user?.email).toBe(user.email)
  })

  it("creates a service-role client that can read created auth users", async () => {
    const { user } = await signInAsTestUser()
    const admin = createAdminClient()
    const { data, error } = await admin.auth.admin.getUserById(user.userId)

    expect(error).toBeNull()
    expect(data.user?.id).toBe(user.userId)
    expect(data.user?.email).toBe(user.email)
  })
})
