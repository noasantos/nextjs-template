import { defineConfig, devices } from "@playwright/test"

/**
 * E2E Test Configuration for Next.js Template
 *
 * CRITICAL: This E2E suite tests ONLY essential authentication flows.
 * Do not add E2E tests for other features - use unit/integration tests instead.
 *
 * Essential flows covered:
 * 1. Sign-in with valid credentials
 * 2. Sign-in with invalid credentials (error handling)
 * 3. Sign-out
 * 4. Protected route redirection
 */

export default defineConfig({
  testDir: "./apps/example/tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    baseURL: process.env.E2E_BASE_URL || "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },

  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "firefox",
      use: { ...devices["Desktop Firefox"] },
    },
    {
      name: "webkit",
      use: { ...devices["Desktop Safari"] },
    },
  ],

  webServer: {
    command: "pnpm --filter=./apps/example dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
})
