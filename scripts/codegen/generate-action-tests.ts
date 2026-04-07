#!/usr/bin/env tsx
/**
 * Generate unit tests for Server Actions
 *
 * Usage:
 *   pnpm tsx scripts/codegen/generate-action-tests.ts --write
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, resolve } from "node:path"

import type { ActionSemanticPlan } from "./actions-semantic-plan"

const repoRoot = resolve(process.cwd())

function toKebabCase(str: string): string {
  return str
    .replace(/([a-z])([A-Z])/g, "$1-$2")
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
}

function toCamelCase(str: string): string {
  return toKebabCase(str).replace(/-([a-z])/g, (_, c: string) => c.toUpperCase())
}

function generateActionTest(plan: ActionSemanticPlan): string {
  const domainKebab = toKebabCase(plan.domainId)
  const tableKebab = toKebabCase(plan.table)
  const methodCamel = toCamelCase(plan.method)
  const actionName = plan.actionName
  const isWriteOperation = ["insert", "update", "delete"].includes(plan.method)

  return `/**
 * Unit tests for ${actionName}
 * 
 * @codegen-generated
 */
import { describe, expect, it, vi, beforeEach } from "vitest"

import { ${actionName} } from "@workspace/supabase-data/actions/${domainKebab}/${tableKebab}-${methodCamel}.codegen"

vi.mock("@workspace/supabase-auth/session/get-claims", () => ({
  getClaims: vi.fn(),
}))

vi.mock("@workspace/supabase-auth/server/create-server-auth-client", () => ({
  createServerAuthClient: vi.fn(),
}))

vi.mock("@workspace/logging/server", () => ({
  logServerEvent: vi.fn(),
}))

describe("${actionName}", () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe("Authentication", () => {
    it("should throw Unauthorized when not authenticated", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      vi.mocked(getClaims).mockResolvedValue({ claims: null } as any)

      await expect(${actionName}({} as any)).rejects.toThrow("Unauthorized")
    })
  })

  describe("Input Validation", () => {
    it("should validate input with Zod schema", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      vi.mocked(getClaims).mockResolvedValue({ claims: { sub: "test-user-id" } } as any)

      await expect(${actionName}({ invalid: "data" } as any)).rejects.toThrow()
    })
${
  isWriteOperation
    ? `
    it("should accept valid input for ${plan.method} operation", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      vi.mocked(getClaims).mockResolvedValue({ claims: { sub: "test-user-id" } } as any)

      const { createServerAuthClient } = await import("@workspace/supabase-auth/server/create-server-auth-client")
      vi.mocked(createServerAuthClient).mockResolvedValue({
        from: vi.fn().mockReturnThis(),
        insert: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({ data: { id: "test" }, error: null }),
      } as any)

      await expect(${actionName}({} as any)).resolves.toBeDefined()
    })
`
    : `
    it("should accept valid input for ${plan.method} operation", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      vi.mocked(getClaims).mockResolvedValue({ claims: { sub: "test-user-id" } } as any)

      const { createServerAuthClient } = await import("@workspace/supabase-auth/server/create-server-auth-client")
      vi.mocked(createServerAuthClient).mockResolvedValue({
        from: vi.fn().mockReturnThis(),
        select: vi.fn().mockReturnThis(),
        eq: vi.fn().mockReturnThis(),
        single: vi.fn().mockResolvedValue({ data: { id: "test" }, error: null }),
      } as any)

      await expect(${actionName}({ id: "valid-uuid" } as any)).resolves.toBeDefined()
    })
`
}
  })

  describe("Logging", () => {
    it("should log security audit on unauthorized access", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      const { logServerEvent } = await import("@workspace/logging/server")
      
      vi.mocked(getClaims).mockResolvedValue({ claims: null } as any)

      try {
        await ${actionName}({} as any)
      } catch {
        // Expected
      }

      expect(logServerEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          eventFamily: "security.audit",
          eventName: expect.stringContaining("unauthorized"),
          outcome: "failure",
        })
      )
    })
  })
})
`
}

// Main
if (import.meta.url === `file://${process.argv[1]}`) {
  const write = process.argv.includes("--write")
  const planPath =
    process.argv.find((_, i) => process.argv[i - 1] === "--plan") ??
    resolve(repoRoot, "config/action-semantic-plan.json")

  if (!existsSync(planPath)) {
    process.stderr.write("❌ action-semantic-plan.json not found\n")
    process.exit(1)
  }

  const plan = JSON.parse(readFileSync(planPath, "utf8")) as ActionSemanticPlan

  console.log(`📝 Generating action tests...`)
  console.log(`   Actions: ${plan.actions.length}`)
  console.log("")

  let generated = 0
  const testsDir = join(repoRoot, "tests/unit/supabase-data/actions")

  for (const action of plan.actions) {
    const domainKebab = toKebabCase(action.domainId)
    const tableKebab = toKebabCase(action.table)
    const methodCamel = toCamelCase(action.method)

    const testFile = join(
      testsDir,
      domainKebab,
      `${tableKebab}-${methodCamel}.codegen.action.test.ts`
    )

    if (!write) {
      console.log(
        `Would generate: ${domainKebab}/${tableKebab}-${methodCamel}.codegen.action.test.ts`
      )
      generated++
      continue
    }

    mkdirSync(dirname(testFile), { recursive: true })
    const testContent = generateActionTest(action)
    writeFileSync(testFile, testContent, "utf8")
    generated++
    console.log(`✅ Generated: ${domainKebab}/${tableKebab}-${methodCamel}.codegen.action.test.ts`)
  }

  console.log("")
  console.log(`🎉 Generated ${generated} action test files!`)
}

export { generateActionTest }
