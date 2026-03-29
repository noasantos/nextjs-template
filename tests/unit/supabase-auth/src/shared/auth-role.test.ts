/**
 * `expandRolesForAdmin` is a **template helper** (admin ⇒ all `AUTH_ROLES`). Remove or
 * replace when your product does not use that pattern.
 */
import { describe, expect, it } from "vitest"

import { AUTH_ROLES, expandRolesForAdmin } from "@workspace/supabase-auth/shared/auth-role"

describe("expandRolesForAdmin (template)", () => {
  it("returns every AuthRole in order when admin is present", () => {
    expect(expandRolesForAdmin(["admin"])).toEqual([...AUTH_ROLES])
  })

  it("returns a copy of the input when admin is absent", () => {
    const out = expandRolesForAdmin([])
    expect(out).toEqual([])
  })
})
