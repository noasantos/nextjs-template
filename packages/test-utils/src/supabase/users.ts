import {
  createAnonTestClient,
  createServiceRoleTestClient,
} from "@workspace/test-utils/supabase/clients"

type CreateTestUserOptions = {
  appMetadata?: Record<string, unknown>
  email?: string
  password?: string
}

type TestUser = {
  email: string
  password: string
  userId: string
}

async function createTestUser(overrides: CreateTestUserOptions = {}): Promise<TestUser> {
  const admin = await createServiceRoleTestClient()
  const email = overrides.email ?? `user.${crypto.randomUUID()}@example.test`
  const password = overrides.password ?? process.env.TEST_USER_PASSWORD ?? "Password123!"

  const { data, error } = await admin.auth.admin.createUser({
    app_metadata: overrides.appMetadata ?? {},
    email,
    email_confirm: true,
    password,
  })

  if (error || !data.user) {
    throw error ?? new Error("Failed to create test user")
  }

  return {
    email,
    password,
    userId: data.user.id,
  }
}

async function signInAsTestUser(overrides: CreateTestUserOptions = {}) {
  const user = await createTestUser(overrides)
  const client = await createAnonTestClient()
  const { error } = await client.auth.signInWithPassword({
    email: user.email,
    password: user.password,
  })

  if (error) {
    throw error
  }

  return {
    client,
    user,
  }
}

export { createTestUser, signInAsTestUser, type CreateTestUserOptions, type TestUser }
