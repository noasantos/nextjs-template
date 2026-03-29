/**
 * Pure parsing of JWT-shaped objects → `getAccessFromClaims`.
 *
 * - Register real permission codes in `AUTH_PERMISSIONS` / `PERMISSIONS` before using `requirePermission`.
 * - Role slugs must match `AuthRole` (`auth-role.ts`) and typically `app_roles` seed rows.
 */
import { describe, expect, it } from "vitest"

import { getAccessFromClaims } from "@workspace/supabase-auth/shared/get-access-from-claims"
import { ACCESS_CONTROL_TEMPLATE } from "@workspace/supabase-auth/testing/access-control-template"

const { exampleJwtPermission: P, privilegedRole: R } = ACCESS_CONTROL_TEMPLATE

describe("getAccessFromClaims (JWT → access DTO)", () => {
  it("dedupes roles and permissions; parses numeric access_version", () => {
    expect(
      getAccessFromClaims({
        app_metadata: {
          access_version: 3,
          permissions: [P, P],
          roles: [R, R],
        },
        user_metadata: {},
      })
    ).toEqual({
      accessVersion: 3,
      permissions: [P],
      roles: [R],
      subscription: {},
    })
  })

  it("merges valid permissions from user_metadata when app_metadata has junk", () => {
    expect(
      getAccessFromClaims({
        app_metadata: {
          access_version: "nope",
          permissions: ["invalid.permission"],
          roles: ["invalid-role"],
        },
        user_metadata: {
          permissions: [P],
          role: R,
        },
      })
    ).toEqual({
      accessVersion: null,
      permissions: [P],
      roles: [R],
      subscription: {},
    })
  })
})
