/**
 * Database test setup
 *
 * This file initializes the Supabase test client
 * and manages database lifecycle for integration tests
 */
import { createClient } from "@supabase/supabase-js"
import { beforeAll, afterAll } from "vitest"

// Test Supabase credentials (should come from .env.test)
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "http://127.0.0.1:54321"
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || "test-key"

export const testClient = createClient(supabaseUrl, supabaseKey)

// Global setup for DB tests
beforeAll(async () => {
  // Verify DB connection
  const { error } = await testClient.from("profiles").select("count").single()
  if (error && error.code !== "PGRST116") {
    process.stderr.write(
      "⚠️  Supabase connection failed. Make sure local Supabase is running:\n   pnpm supabase:start\n"
    )
  }
})

// Global cleanup
afterAll(async () => {
  // Cleanup can be added here if needed
})
