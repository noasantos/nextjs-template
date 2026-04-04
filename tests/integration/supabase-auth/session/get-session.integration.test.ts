import { createServerClient } from "@supabase/ssr"
import { describe, expect, it, vi } from "vitest"

import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"
import { getSession } from "@workspace/supabase-auth/session/get-session"
import { getSupabaseCookieOptions } from "@workspace/supabase-auth/shared/get-supabase-cookie-options"
import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import type { Database } from "@workspace/supabase-infra/types/database"
import { createTestUser } from "@workspace/test-utils/supabase/users"

const { cookiesMock } = vi.hoisted(() => ({
  cookiesMock: vi.fn(),
}))

vi.mock("next/headers", () => ({
  cookies: cookiesMock,
}))

function createNextCookieStore() {
  const jar = new Map<string, string>()
  return {
    getAll: () => [...jar.entries()].map(([name, value]) => ({ name, value })),
    set: (name: string, value: string, ..._rest: unknown[]) => {
      void _rest
      jar.set(name, value)
    },
  }
}

describe("server auth + Next cookie adapter (integration)", () => {
  it("persists session in the cookie jar and reads it via createServerAuthClient and getSession", async () => {
    const cookieStore = createNextCookieStore()
    cookiesMock.mockResolvedValue(cookieStore)

    const { supabaseUrl, supabasePublishableKey } = getSupabasePublicEnv()
    const bootstrap = createServerClient<Database>(supabaseUrl, supabasePublishableKey, {
      cookieOptions: getSupabaseCookieOptions(),
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (cookiesToSet) => {
          try {
            cookiesToSet.forEach(({ name, options, value }) => {
              cookieStore.set(name, value, options)
            })
          } catch {
            // Mirrors create-server-auth-client: RSC may not allow writes.
          }
        },
      },
    })

    const user = await createTestUser()
    const { error } = await bootstrap.auth.signInWithPassword({
      email: user.email,
      password: user.password,
    })

    expect(error).toBeNull()

    const { data: bootstrapUser } = await bootstrap.auth.getUser()
    expect(bootstrapUser.user?.id).toBe(user.userId)

    const client = await createServerAuthClient()
    const { data: clientUser } = await client.auth.getUser()
    expect(clientUser.user?.id).toBe(user.userId)

    const session = await getSession()
    expect(session).not.toBeNull()
    const { data: afterGetSession } = await client.auth.getUser()
    expect(afterGetSession.user?.id).toBe(user.userId)
  })
})
