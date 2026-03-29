/**
 * `syncUserRoles` delegates to `syncUserAccess` (service role RPC + GoTrue metadata).
 * Mock return shape mirrors real DTO; privileged role slug from template.
 */
import { afterEach, describe, expect, it, vi } from "vitest"

import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"

const { privilegedRole: R } = ACCESS_CONTROL_TEMPLATE

const { syncUserAccessMock } = vi.hoisted(() => ({
  syncUserAccessMock: vi.fn(),
}))

vi.mock("@workspace/supabase-data/actions/user-access/sync-user-access", () => ({
  syncUserAccess: syncUserAccessMock,
}))

import { syncUserRoles } from "@workspace/supabase-data/actions/user-roles/sync-user-roles"

const userId = "550e8400-e29b-41d4-a716-446655440000"

afterEach(() => {
  syncUserAccessMock.mockReset()
  vi.useRealTimers()
})

describe("syncUserRoles (wraps syncUserAccess)", () => {
  it("maps each persisted role to a DTO row with ISO createdAt", async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date("2026-03-25T14:30:00.000Z"))

    syncUserAccessMock.mockResolvedValue({
      accessVersion: 1,
      permissions: [],
      roles: [R],
      subscription: {},
      userId,
    })

    await expect(syncUserRoles(userId, [R])).resolves.toEqual([
      {
        createdAt: "2026-03-25T14:30:00.000Z",
        role: R,
        userId,
      },
    ])

    expect(syncUserAccessMock).toHaveBeenCalledOnce()
    expect(syncUserAccessMock).toHaveBeenCalledWith(userId, [R])
  })

  it("returns an empty array when sync yields no roles", async () => {
    syncUserAccessMock.mockResolvedValue({
      accessVersion: 1,
      permissions: [],
      roles: [],
      subscription: {},
      userId,
    })

    await expect(syncUserRoles(userId, [])).resolves.toEqual([])
  })

  it("propagates errors from syncUserAccess", async () => {
    syncUserAccessMock.mockRejectedValue(
      new Error("simulated GoTrue failure after DB sync")
    )

    await expect(syncUserRoles(userId, [R])).rejects.toThrow(
      "simulated GoTrue failure after DB sync"
    )
  })
})
