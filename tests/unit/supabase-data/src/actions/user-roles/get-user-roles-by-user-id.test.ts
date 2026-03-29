import type { SupabaseClient } from "@supabase/supabase-js"
import { afterEach, describe, expect, it, vi } from "vitest"

import { SupabaseRepositoryError } from "@workspace/supabase-data/lib/supabase-repository-error"
import { UserRoleSupabaseRepository } from "@workspace/supabase-data/modules/user-roles/infrastructure/repositories/user-role-supabase.repository"
import { getUserRolesByUserId } from "@workspace/supabase-data/actions/user-roles/get-user-roles-by-user-id"

afterEach(() => {
  vi.restoreAllMocks()
})

describe("getUserRolesByUserId", () => {
  const userId = "00000000-0000-4000-8000-000000000001"
  const supabase = {} as SupabaseClient

  it("returns roles from the repository", async () => {
    const expected = [
      {
        createdAt: "2026-03-25T00:00:00.000Z",
        role: "admin" as const,
        userId,
      },
    ]
    vi.spyOn(
      UserRoleSupabaseRepository.prototype,
      "findByUserId"
    ).mockResolvedValue(expected)

    await expect(getUserRolesByUserId(supabase, userId)).resolves.toEqual(
      expected
    )
  })

  it("forwards the user id to the repository", async () => {
    const spy = vi
      .spyOn(UserRoleSupabaseRepository.prototype, "findByUserId")
      .mockResolvedValue([])

    await getUserRolesByUserId(supabase, userId)

    expect(spy).toHaveBeenCalledWith(userId)
  })

  it("propagates repository errors", async () => {
    vi.spyOn(
      UserRoleSupabaseRepository.prototype,
      "findByUserId"
    ).mockRejectedValue(
      new SupabaseRepositoryError("Failed to load user roles.", {
        cause: new Error("db"),
      })
    )

    await expect(getUserRolesByUserId(supabase, userId)).rejects.toThrow(
      SupabaseRepositoryError
    )
  })
})
