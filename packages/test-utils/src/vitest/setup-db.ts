import { afterEach, beforeAll, vi } from "vitest"

import { ensureSupabaseTestEnv } from "@workspace/test-utils/supabase/env"

vi.mock("server-only", () => ({}))

beforeAll(async () => {
  await ensureSupabaseTestEnv()
})

afterEach(() => {
  vi.restoreAllMocks()
  vi.useRealTimers()
})
