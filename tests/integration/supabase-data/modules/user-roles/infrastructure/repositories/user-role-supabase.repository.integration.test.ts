/**
 * **RLS + repository pattern:** privileged users (template: `ACCESS_CONTROL_TEMPLATE.privilegedRole`
 * in JWT + `user_roles`) may replace another user’s roles; ordinary members cannot.
 *
 * Swap the privileged slug in seed + policies when your product uses different role names.
 */
import { describe, expect, it } from "vitest"

import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"
import { UserRoleSupabaseRepository } from "@workspace/supabase-data/modules/user-roles/infrastructure/repositories/user-role-supabase.repository"
import { createServiceRoleTestClient } from "@workspace/test-utils/supabase/clients"
import { createTestUser, signInAsTestUser } from "@workspace/test-utils/supabase/users"

const { memberRole, privilegedRole } = ACCESS_CONTROL_TEMPLATE

describe("UserRoleSupabaseRepository (integration template)", () => {
  it("allows a JWT-privileged caller to replace roles for another user", async () => {
    const admin = await createServiceRoleTestClient()
    const target = await createTestUser()
    const { client, user } = await signInAsTestUser({
      appMetadata: {
        roles: [privilegedRole],
      },
    })

    await admin.from("user_roles").insert({
      role: privilegedRole,
      user_id: user.userId,
    })

    const repository = new UserRoleSupabaseRepository(client)

    const replaced = await repository.replaceUserRoles(target.userId, [privilegedRole])
    const loaded = await repository.findByUserId(target.userId)

    expect(replaced).toHaveLength(1)
    expect(loaded.map((entry) => entry.role)).toEqual([privilegedRole])
  })

  it("rejects replace when the session lacks the privileged role", async () => {
    const admin = await createServiceRoleTestClient()
    const target = await createTestUser()
    const { client } = await signInAsTestUser({
      appMetadata: {
        roles: [memberRole],
      },
    })
    const repository = new UserRoleSupabaseRepository(client)

    await expect(repository.replaceUserRoles(target.userId, [privilegedRole])).rejects.toThrow(
      "Failed to persist user roles."
    )

    const loaded = await admin.from("user_roles").select("role").eq("user_id", target.userId)

    expect(loaded.error).toBeNull()
    expect(loaded.data).toEqual([])
  })
})
