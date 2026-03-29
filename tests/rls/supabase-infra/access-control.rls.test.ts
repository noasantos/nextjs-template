/**
 * **user_roles RLS (template):** users read only their own rows unless JWT satisfies
 * `auth_is_admin()` (hard-coded `admin` slug today — change in a migration when you rename).
 */
import { describe, expect, it } from "vitest"

import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"
import { createServiceRoleTestClient } from "@workspace/test-utils/supabase/clients"
import { signInAsTestUser } from "@workspace/test-utils/supabase/users"

const { memberRole, privilegedRole } = ACCESS_CONTROL_TEMPLATE

describe("user_roles RLS (template)", () => {
  it("hides other users’ role rows from a member session", async () => {
    const admin = await createServiceRoleTestClient()
    const actor = await signInAsTestUser()
    const { user: target } = await signInAsTestUser()

    await admin.from("user_roles").insert({
      role: privilegedRole,
      user_id: target.userId,
    })

    const result = await actor.client
      .from("user_roles")
      .select("user_id, role")
      .eq("user_id", target.userId)

    expect(result.error).toBeNull()
    expect(result.data).toEqual([])
  })

  it("lets a privileged JWT read another user’s roles (policy uses auth_is_admin)", async () => {
    const admin = await createServiceRoleTestClient()
    const { client, user } = await signInAsTestUser({
      appMetadata: {
        roles: [privilegedRole],
      },
    })
    const target = await signInAsTestUser()

    await admin.from("user_roles").insert([
      { role: privilegedRole, user_id: user.userId },
      { role: memberRole, user_id: target.user.userId },
    ])

    const select = await client
      .from("user_roles")
      .select("user_id, role")
      .eq("user_id", target.user.userId)

    expect(select.error).toBeNull()
    expect(select.data).toEqual([
      {
        role: memberRole,
        user_id: target.user.userId,
      },
    ])
  })
})
