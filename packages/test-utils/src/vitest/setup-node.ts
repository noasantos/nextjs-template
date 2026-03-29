import { afterEach } from "vitest"
import { vi } from "vitest"

vi.mock("server-only", () => ({}))

afterEach(() => {
  vi.restoreAllMocks()
  vi.unstubAllEnvs()
  vi.useRealTimers()
})
