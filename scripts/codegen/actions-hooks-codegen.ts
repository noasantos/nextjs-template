#!/usr/bin/env tsx
/**
 * Automated codegen for Server Actions and TanStack Query hooks.
 *
 * Phase A - Deterministic generation from repository-plan.json
 *
 * Usage:
 *   pnpm codegen:actions-hooks --write
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join, relative, resolve } from "node:path"

import { planRepositoryImportSpecifier } from "../../packages/codegen-tools/src/backend-codegen/plan-module-paths"
import {
  parseDomainMapJson,
  type DomainEntry,
} from "../../packages/codegen-tools/src/domain-map-schema"
import { parseRepositoryPlanJson } from "../../packages/codegen-tools/src/repository-plan-schema"

interface ActionsHooksCodegenOptions {
  repoRoot: string
  typesPath: string
  planPath: string
  domainMapPath: string
  checkOnly: boolean
  force?: boolean
  domainFilter?: string
}

interface CodegenResult {
  ok: boolean
  filesWritten: string[]
  errors: string[]
  actionsGenerated: number
  hooksGenerated: number
  queryKeysUpdated: number
}

interface TableDefinition {
  Row: Record<string, unknown>
  Insert: Record<string, unknown>
  Update: Record<string, unknown>
  Relationships: unknown[]
}

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

function toPascalCase(str: string): string {
  const camel = toCamelCase(str)
  return camel.charAt(0).toUpperCase() + camel.slice(1)
}

function ensureDir(filePath: string): void {
  const dir = dirname(filePath)
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true })
  }
}

function generateServerAction(
  domainId: string,
  tableName: string,
  methodName: string,
  tableDef: TableDefinition,
  domainConfig?: Pick<DomainEntry, "auth">
): string {
  const domainKebab = toKebabCase(domainId)
  const tableKebab = toKebabCase(tableName)
  const methodCamel = toCamelCase(methodName)
  const actionName = `${methodCamel}${toPascalCase(tableName)}Action`
  const repositoryClassName = `${toPascalCase(tableName)}SupabaseRepository`
  const repositoryModule = domainKebab

  // Domain map `auth` may extend beyond Zod enum at runtime; keep flags for template branches.
  type AuthFlag = NonNullable<DomainEntry["auth"]> | "tenant" | "role-gated"
  const authFlag = domainConfig?.auth as AuthFlag | undefined
  const isPublic = authFlag === "public"
  const isRoleGated = authFlag === "role-gated"
  const isTenantScoped = authFlag === "tenant" || authFlag === undefined

  // Generate audit safe fields constant
  const auditSafeFields = '["id", "createdAt", "updatedAt"] as const'

  // Generate role check if needed
  const roleCheckCode = isRoleGated
    ? `
  // 3. Role check (role-gated table)
  if (claims.app_metadata?.role !== "psychologist") {
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "${domainKebab}.${tableKebab}.${methodCamel}",
      durationMs: 0,
      eventFamily: "security.audit",
      eventName: "role_access_denied",
      operation: "${methodName}",
      operationType: "auth",
      outcome: "failure",
      service: "supabase-data",
    })
    throw new Error("Access denied")
  }
`
    : ""

  // Generate tenant resolution if needed
  const tenantResolutionCode = isTenantScoped
    ? `
  // 4. Tenant resolution — in action, not in repo
  const psychologistId = await getPsychologistIdForUser(userId)
  if (!psychologistId) {
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "${domainKebab}.${tableKebab}.${methodCamel}",
      durationMs: 0,
      eventFamily: "security.audit",
      eventName: "tenant_access_denied",
      operation: "${methodName}",
      operationType: "auth",
      outcome: "failure",
      service: "supabase-data",
    })
    throw new Error("Access denied")
  }
  void psychologistId // Reserved for tenant-scoped filters; RLS may already enforce scope.
`
    : ""

  // Repository methods have heterogeneous signatures; stubs use narrow casts until TODO schemas are filled.
  const repositoryCallCode = (() => {
    switch (methodName) {
      case "list":
        // @type-escape: generated action stub — list params unknown until semantic plan fills Zod input
        return `const result = await repository.list(validated as never)`
      case "findById":
        // @type-escape: generated action stub — id shape from validated after TODO input schema
        return `const result = await repository.findById((validated as unknown as { id: string }).id)`
      case "insert":
        // @type-escape: generated action stub — insert payload unknown until TODO input schema
        return `const result = await repository.insert(validated as never)`
      case "update":
        // @type-escape: generated action stub — id + patch unknown until TODO input schema
        return `const result = await repository.update((validated as unknown as { id: string }).id, validated as never)`
      case "delete":
        // @type-escape: generated action stub — delete id unknown until TODO input schema
        return `await repository.delete((validated as unknown as { id: string }).id)`
      default:
        return `const result = await (repository as Record<string, (v: unknown) => Promise<unknown>>)["${methodCamel}"](validated)`
    }
  })()

  // Generate imports based on table type (tenant helper only when tenant resolution runs)
  const imports = isPublic
    ? `import { createServerAnonClient } from "@workspace/supabase-auth/server/create-server-anon-client"`
    : isTenantScoped
      ? `import { requireAuth } from "@workspace/supabase-data/lib/auth/require-auth"
import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"
import { getPsychologistIdForUser } from "@workspace/supabase-data/lib/auth/resolve-tenant"`
      : `import { requireAuth } from "@workspace/supabase-data/lib/auth/require-auth"
import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"`

  const successReturn =
    methodName === "delete"
      ? `return null as ${toPascalCase(tableName)}${toPascalCase(methodName)}Output`
      : "return result"

  return `/**
 * ${toPascalCase(methodName)}${toPascalCase(tableName)} Server Action
 * 
 * Handles ${methodName} operation for ${tableName}.
 * 
 * ## Usage
 * 
 * Example:
 * \`\`\`typescript
 * import { ${actionName} } from "@workspace/supabase-data/actions/${domainKebab}/${tableKebab}-${methodCamel}.codegen"
 * 
 * const result = await ${actionName}(input)
 * \`\`\`
 * 
 * @module @workspace/supabase-data/actions/${domainKebab}/${tableKebab}-${methodCamel}
 * codegen:actions-hooks (generated) — do not hand-edit
 */
"use server"

import { z } from "zod"

${imports}
import { ${repositoryClassName} } from "${planRepositoryImportSpecifier(repositoryModule, tableKebab)}"
import { logServerEvent } from "@workspace/logging/server"
import { sanitizeForAudit } from "@workspace/supabase-data/lib/audit/sanitize-phi"

/**
 * Audit-safe fields for this table (HIPAA §164.312(b) compliant)
 * 
 * These fields are safe to log in error metadata without exposing PHI.
 */
const AUDIT_SAFE_FIELDS = ${auditSafeFields}

/**
 * Input schema for ${actionName}
 * 
 * Uses Zod v4 syntax (top-level APIs, not z.string().email() etc.)
 */
const ${toPascalCase(tableName)}${toPascalCase(methodName)}InputSchema = z.object({
  // TODO: Define input fields based on ${tableName}.${methodName} requirements
  // Example for insert (Zod v4 syntax):
  // email: z.email({ error: "Invalid email" }),
  // id: z.uuid({ error: "Invalid UUID" }),
  // url: z.url({ error: "Invalid URL" }),
  // datetime: z.iso.datetime({ error: "Invalid datetime" }),
  // metadata: z.record(z.string(), z.unknown()).optional(),
})

/**
 * Input type for ${actionName}
 */
export type ${toPascalCase(tableName)}${toPascalCase(methodName)}Input = z.infer<typeof ${toPascalCase(tableName)}${toPascalCase(methodName)}InputSchema>

/**
 * Output type for ${actionName} — unknown until the action is wired to real DTOs / port types.
 */
export type ${toPascalCase(tableName)}${toPascalCase(methodName)}Output = unknown

/**
 * ${toPascalCase(methodName)}${toPascalCase(tableName)} Server Action
 * 
 * @param input - Action input
 */
export async function ${actionName}(
  input: ${toPascalCase(tableName)}${toPascalCase(methodName)}Input
): Promise<${toPascalCase(tableName)}${toPascalCase(methodName)}Output> {
  const startedAt = Date.now()
  let actorIdForLog = "unknown"

  try {${
    isPublic
      ? `
    // 1. Public read-only — no auth required
    const supabase = await createServerAnonClient()
    const repository = new ${repositoryClassName}(supabase)
    
    // 2. Execute operation
    ${repositoryCallCode}

    // 3. Log success
    await logServerEvent({
      actorId: "anonymous",
      actorType: "unknown",
      component: "${domainKebab}.${tableKebab}.${methodCamel}",
      durationMs: Date.now() - startedAt,
      eventFamily: "action.lifecycle",
      eventName: "${methodCamel}_${tableKebab}_success",
      operation: "${methodName}",
      operationType: "action",
      outcome: "success",
      service: "supabase-data",
    })

    ${successReturn}`
      : `
    // 1. Identity + rate limit (SSOT via requireAuth)
    const { userId${isRoleGated ? ", claims" : ""} } = await requireAuth({
      action: "${methodCamel}_${tableKebab}",
    })
    actorIdForLog = userId${roleCheckCode}${tenantResolutionCode}
    // 2. Input validation — before any DB call
    const validated = ${toPascalCase(tableName)}${toPascalCase(methodName)}InputSchema.parse(input)

    // 3. Auth client — created after all guards pass
    const supabase = await createServerAuthClient()
    const repository = new ${repositoryClassName}(supabase)
    
    // 4. Execute operation — pass resolved context explicitly
    ${repositoryCallCode}

    // 5. Log success
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "${domainKebab}.${tableKebab}.${methodCamel}",
      durationMs: Date.now() - startedAt,
      eventFamily: "action.lifecycle",
      eventName: "${methodCamel}_${tableKebab}_success",
      operation: "${methodName}",
      operationType: "action",
      outcome: "success",
      service: "supabase-data",
    })

    ${successReturn}`
  }
  } catch (error) {
    // 6. Log error with sanitized metadata (HIPAA compliant)
    await logServerEvent({
      actorId: ${isPublic ? '"anonymous"' : "actorIdForLog"},
      actorType: ${isPublic ? '"unknown"' : '"user"'},
      component: "${domainKebab}.${tableKebab}.${methodCamel}",
      durationMs: Date.now() - startedAt,
      eventFamily: "action.lifecycle",
      eventName: "${methodCamel}_${tableKebab}_failed",
      operation: "${methodName}",
      operationType: "action",
      outcome: "failure",
      error,
      metadata: sanitizeForAudit(input as Record<string, unknown>, AUDIT_SAFE_FIELDS),
      service: "supabase-data",
    })

    throw error
  }
}
`
}

function generateQueryKeys(
  domainId: string,
  tables: Array<{ tableName: string; methods: string[] }>
): string {
  const domainKebab = toKebabCase(domainId)
  const domainCamel = toCamelCase(domainId)
  const exportName = `${domainCamel}QueryKeys`

  let keysContent = ""
  for (const { tableName, methods } of tables) {
    const tableCamel = toCamelCase(tableName)
    const hasList = methods.includes("list")
    const hasFindById = methods.includes("findById")

    if (hasList) {
      keysContent += `  ${tableCamel}: () => [...${exportName}.all, "${toKebabCase(tableName)}"] as const,
  ${tableCamel}List: (filters?: Record<string, unknown>) =>
    [...${exportName}.${tableCamel}(), "list", filters ?? {}] as const,
`
    } else if (hasFindById) {
      keysContent += `  ${tableCamel}: () => [...${exportName}.all, "${toKebabCase(tableName)}"] as const,
  ${tableCamel}ById: (id: string) =>
    [...${exportName}.${tableCamel}(), "byId", id] as const,
`
    }
  }

  return `/**
 * TanStack Query key factory for domain "${domainKebab}".
 * Import keys from this module only — avoid string literals in hooks/components.
 * 
 * @module @workspace/supabase-data/hooks/${domainKebab}/query-keys.codegen
 * codegen:actions-hooks (generated) — do not hand-edit
 */
export const ${exportName} = {
  all: ["${domainKebab}"] as const,
${keysContent}}
`
}

function generateQueryHook(domainId: string, tableName: string, actionName: string): string {
  const domainKebab = toKebabCase(domainId)
  const tableKebab = toKebabCase(tableName)
  const domainCamel = toCamelCase(domainId)
  const tableCamel = toCamelCase(tableName)
  const queryKeysExport = `${domainCamel}QueryKeys`
  const hookName = `use${toPascalCase(tableName)}Query`

  return `/**
 * ${hookName} — TanStack Query wrapper for a Server Action.
 * 
 * TODO: Wire the Server Action import and replace the queryFn body.
 * Do not add console.log — observability lives in the action (logServerEvent).
 * 
 * @module @workspace/supabase-data/hooks/${domainKebab}/use-${tableKebab}-query.hook
 * codegen:actions-hooks (generated) — do not hand-edit
 */
"use client"

import { useQuery, type UseQueryResult } from "@tanstack/react-query"

import { ${queryKeysExport} } from "@workspace/supabase-data/hooks/${domainKebab}/query-keys.codegen"

// TODO: import { ${actionName} } from "@workspace/supabase-data/actions/${domainKebab}/${tableKebab}-list.codegen"
// TODO: Narrow the input type based on your action's requirements
type QueryFilters = Record<string, unknown>

export function ${hookName}(filters?: QueryFilters): UseQueryResult<unknown, Error> {
  return useQuery({
    queryKey: ${queryKeysExport}.${tableCamel}List(filters),
    queryFn: async () => {
      // TODO: Replace with actual action call
      // return ${actionName}(filters ?? {})
      throw new Error("Wire Server Action in queryFn")
    },
  })
}
`
}

function generateMutationHook(domainId: string, tableName: string, actionName: string): string {
  const domainKebab = toKebabCase(domainId)
  const tableKebab = toKebabCase(tableName)
  const domainCamel = toCamelCase(domainId)
  const tableCamel = toCamelCase(tableName)
  const queryKeysExport = `${domainCamel}QueryKeys`
  const hookName = `use${toPascalCase(tableName)}Mutation`

  return `/**
 * ${hookName} — TanStack Query mutation wrapper for a Server Action.
 * 
 * TODO: Import the Server Action, narrow \`_input\`, and tune invalidation (prefer precise keys).
 * Do not add console.log — use structured logging in the action (logServerEvent).
 * 
 * @module @workspace/supabase-data/hooks/${domainKebab}/use-${tableKebab}-mutation.hook
 * codegen:actions-hooks (generated) — do not hand-edit
 */
"use client"

import { useMutation, useQueryClient, type UseMutationResult } from "@tanstack/react-query"

import { ${queryKeysExport} } from "@workspace/supabase-data/hooks/${domainKebab}/query-keys.codegen"

// TODO: import { ${actionName} } from "@workspace/supabase-data/actions/${domainKebab}/${tableKebab}-insert.codegen"
// TODO: Narrow the input type based on your action's requirements
type MutationInput = unknown

export function ${hookName}(): UseMutationResult<unknown, Error, MutationInput, unknown> {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: async (_input: MutationInput) => {
      // TODO: Replace with actual action call
      // return ${actionName}(_input as any)
      throw new Error("Wire Server Action in mutationFn")
    },
    onSettled: async () => {
      // TODO: Invalidate precise query keys
      await queryClient.invalidateQueries({ queryKey: ${queryKeysExport}.${tableCamel}() })
    },
  })
}
`
}

function generateActionTest(
  domainId: string,
  tableName: string,
  methodName: string,
  actionName: string
): string {
  const domainKebab = toKebabCase(domainId)
  const tableKebab = toKebabCase(tableName)
  const methodCamel = toCamelCase(methodName)
  const tablePascal = toPascalCase(tableName)
  const isWriteOperation = ["insert", "update", "delete", "upsert"].includes(methodName)
  const repositoryClassName = `${tablePascal}SupabaseRepository`
  const repositoryImportPath = `@workspace/supabase-data/modules/${domainKebab}/infrastructure/repositories/${tableKebab}-supabase.repository.codegen`
  const repositorySuccessMock = generateActionTestRepositorySuccessMock(methodName)

  return `/**
 * Unit tests for ${actionName}
 * 
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it, vi, beforeEach } from "vitest"

import { ${actionName} } from "@workspace/supabase-data/actions/${domainKebab}/${tableKebab}-${methodCamel}.codegen"

vi.mock("@workspace/supabase-auth/session/get-claims", () => ({
  getClaims: vi.fn(),
}))

vi.mock("@workspace/supabase-auth/server/create-server-auth-client", () => ({
  createServerAuthClient: vi.fn(),
}))

vi.mock("@workspace/supabase-data/lib/auth/rate-limit", () => ({
  checkActionRateLimit: vi.fn(),
}))

vi.mock("${repositoryImportPath}", () => ({
  ${repositoryClassName}: vi.fn(),
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

    it("should log security.audit on unauthorized access", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      const { logServerEvent } = await import("@workspace/logging/server")
      vi.mocked(getClaims).mockResolvedValue({ claims: null } as any)

      await ${actionName}({} as any).catch(() => {})

      expect(logServerEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          eventFamily: "security.audit",
          eventName: "unauthorized_action_attempt",
          outcome: "failure",
        })
      )
    })
  })

  describe("Input Validation", () => {
    it("should validate input with Zod schema", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      const { checkActionRateLimit } = await import("@workspace/supabase-data/lib/auth/rate-limit")
      vi.mocked(getClaims).mockResolvedValue({ claims: { sub: "test-user-id" } } as any)
      vi.mocked(checkActionRateLimit).mockResolvedValue(undefined)

      await expect(${actionName}({ invalid: "data" } as any)).rejects.toThrow()
    })
${
  isWriteOperation
    ? `
    it("should accept valid input for ${methodName} operation", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      const { checkActionRateLimit } = await import("@workspace/supabase-data/lib/auth/rate-limit")
      const { ${repositoryClassName} } = await import("${repositoryImportPath}")
      vi.mocked(getClaims).mockResolvedValue({ claims: { sub: "test-user-id" } } as any)
      vi.mocked(checkActionRateLimit).mockResolvedValue(undefined)

      const { createServerAuthClient } = await import("@workspace/supabase-auth/server/create-server-auth-client")
      vi.mocked(createServerAuthClient).mockResolvedValue({} as any)
      vi.mocked(${repositoryClassName}).mockImplementation(
        function MockRepository() {
          return ${repositorySuccessMock} as any
        } as any
      )

      // TODO: Replace with actual valid input for ${tableName}
      const validInput = {} as any

      await expect(${actionName}(validInput)).resolves.not.toThrow()
    })
`
    : ""
}
  })

  describe("Logging", () => {
    it("should log on success", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      const { checkActionRateLimit } = await import("@workspace/supabase-data/lib/auth/rate-limit")
      const { ${repositoryClassName} } = await import("${repositoryImportPath}")
      const { logServerEvent } = await import("@workspace/logging/server")
      vi.mocked(getClaims).mockResolvedValue({ claims: { sub: "test-user-id" } } as any)
      vi.mocked(checkActionRateLimit).mockResolvedValue(undefined)

      const { createServerAuthClient } = await import("@workspace/supabase-auth/server/create-server-auth-client")
      vi.mocked(createServerAuthClient).mockResolvedValue({} as any)
      vi.mocked(${repositoryClassName}).mockImplementation(
        function MockRepository() {
          return ${repositorySuccessMock} as any
        } as any
      )

      await ${actionName}({} as any).catch(() => {})

      expect(logServerEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          eventFamily: "action.lifecycle",
          eventName: "${methodCamel}_${tableKebab}_success",
          outcome: "success",
        })
      )
    })

    it("should log on error with sanitized metadata", async () => {
      const { getClaims } = await import("@workspace/supabase-auth/session/get-claims")
      const { checkActionRateLimit } = await import("@workspace/supabase-data/lib/auth/rate-limit")
      const { ${repositoryClassName} } = await import("${repositoryImportPath}")
      const { logServerEvent } = await import("@workspace/logging/server")
      vi.mocked(getClaims).mockResolvedValue({ claims: { sub: "test-user-id" } } as any)
      vi.mocked(checkActionRateLimit).mockResolvedValue(undefined)

      const { createServerAuthClient } = await import("@workspace/supabase-auth/server/create-server-auth-client")
      vi.mocked(createServerAuthClient).mockResolvedValue({} as any)
      vi.mocked(${repositoryClassName}).mockImplementation(
        function MockRepository() {
          return {
            findById: vi.fn().mockRejectedValue(new Error("Test error")),
            list: vi.fn().mockRejectedValue(new Error("Test error")),
            insert: vi.fn().mockRejectedValue(new Error("Test error")),
            update: vi.fn().mockRejectedValue(new Error("Test error")),
            delete: vi.fn().mockRejectedValue(new Error("Test error")),
          } as any
        } as any
      )

      await ${actionName}({} as any).catch(() => {})

      expect(logServerEvent).toHaveBeenCalledWith(
        expect.objectContaining({
          eventFamily: "action.lifecycle",
          eventName: "${methodCamel}_${tableKebab}_failed",
          outcome: "failure",
          metadata: expect.objectContaining({
            _sanitized: true,
            _fieldCount: expect.any(Number),
          }),
        })
      )
    })
  })
})
`
}

function generateActionTestRepositorySuccessMock(methodName: string): string {
  if (methodName === "findById") {
    return `{
        findById: vi.fn().mockResolvedValue({ id: "test-id" }),
        list: vi.fn(),
        insert: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      }`
  }

  if (methodName === "list") {
    return `{
        findById: vi.fn(),
        list: vi.fn().mockResolvedValue({ rows: [{ id: "test-id" }] }),
        insert: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      }`
  }

  if (methodName === "delete") {
    return `{
        findById: vi.fn(),
        list: vi.fn(),
        insert: vi.fn(),
        update: vi.fn(),
        delete: vi.fn().mockResolvedValue(undefined),
      }`
  }

  if (methodName === "update" || methodName === "upsert") {
    return `{
        findById: vi.fn(),
        list: vi.fn(),
        insert: vi.fn(),
        update: vi.fn().mockResolvedValue({ id: "test-id" }),
        delete: vi.fn(),
      }`
  }

  return `{
      findById: vi.fn(),
      list: vi.fn(),
      insert: vi.fn().mockResolvedValue({ id: "test-id" }),
      update: vi.fn(),
      delete: vi.fn(),
    }`
}

function generateHookTest(
  domainId: string,
  tableName: string,
  hookName: string,
  hookType: "query" | "mutation"
): string {
  const domainKebab = toKebabCase(domainId)
  const tableKebab = toKebabCase(tableName)
  const queryKeysExport = `${toCamelCase(domainId)}QueryKeys`
  const queryKeysMethod =
    hookType === "query" ? `${toCamelCase(tableName)}List` : `${toCamelCase(tableName)}`
  const queryKeyArgs = hookType === "query" ? "{}" : ""

  return `/**
 * Unit tests for ${hookName}
 * 
 * codegen:actions-hooks (generated) — do not hand-edit
 */
import { describe, expect, it } from "vitest"

import { ${hookName} } from "@workspace/supabase-data/hooks/${domainKebab}/${
    hookType === "query" ? `use-${tableKebab}-query` : `use-${tableKebab}-mutation`
  }.hook.codegen"
import { ${queryKeysExport} } from "@workspace/supabase-data/hooks/${domainKebab}/query-keys.codegen"

describe("${hookName}", () => {
  it("should export the generated hook", () => {
    expect(${hookName}).toBeTypeOf("function")
  })

  it("should expose a query key factory for the generated hook", () => {
    expect(${queryKeysExport}.${queryKeysMethod}(${queryKeyArgs})).toBeDefined()
  })
})
`
}

export function runActionsHooksCodegen(options: ActionsHooksCodegenOptions): CodegenResult {
  const {
    repoRoot,
    typesPath,
    planPath,
    domainMapPath,
    checkOnly,
    force: _force = false,
    domainFilter,
  } = options

  const errors: string[] = []
  const filesWritten: string[] = []
  let actionsGenerated = 0
  let hooksGenerated = 0
  let queryKeysUpdated = 0

  try {
    if (!existsSync(typesPath)) {
      errors.push(`Types file not found: ${typesPath}`)
      return { ok: false, filesWritten, errors, actionsGenerated, hooksGenerated, queryKeysUpdated }
    }

    const planJson = parseRepositoryPlanJson(JSON.parse(readFileSync(planPath, "utf8")))
    const domainMapJson = parseDomainMapJson(JSON.parse(readFileSync(domainMapPath, "utf8")))

    const entries = planJson.entries || []

    const domainEntries = new Map<
      string,
      Array<{ table: string; methods: string[]; entry: (typeof entries)[0] }>
    >()

    for (const entry of entries) {
      let bucket = domainEntries.get(entry.domainId)
      if (!bucket) {
        bucket = []
        domainEntries.set(entry.domainId, bucket)
      }
      bucket.push({
        table: entry.table,
        methods: entry.methods,
        entry,
      })
    }

    if (domainFilter && !domainEntries.has(domainFilter)) {
      errors.push(`Domain "${domainFilter}" not found in repository plan`)
      return { ok: false, filesWritten, errors, actionsGenerated, hooksGenerated, queryKeysUpdated }
    }

    const filteredTables = domainFilter ? domainEntries.get(domainFilter) : undefined
    const domainsToProcess =
      domainFilter && filteredTables
        ? ([[domainFilter, filteredTables]] as const)
        : Array.from(domainEntries.entries())

    for (const [domainId, tables] of domainsToProcess) {
      const domainConfig = domainMapJson.domains.find((d) => d.id === domainId)
      if (!domainConfig || !domainConfig.exposeActions) {
        continue
      }

      const actionsDir = join(repoRoot, "packages/supabase-data/src/actions", domainId)
      const hooksDir = join(repoRoot, "packages/supabase-data/src/hooks", domainId)

      if (!checkOnly) {
        ensureDir(actionsDir)
        ensureDir(hooksDir)
      }

      const queryKeyTables: Array<{ tableName: string; methods: string[] }> = []

      for (const { table, methods } of tables) {
        const tableDef: TableDefinition = {
          Row: {},
          Insert: {},
          Update: {},
          Relationships: [],
        }

        for (const method of methods) {
          const actionFile = join(
            actionsDir,
            `${toKebabCase(table)}-${toCamelCase(method)}.codegen.ts`
          )
          const actionName = `${toCamelCase(method)}${toPascalCase(table)}Action`

          if (!checkOnly) {
            const actionContent = generateServerAction(
              domainId,
              table,
              method,
              tableDef,
              domainConfig
            )
            ensureDir(actionFile)
            writeFileSync(actionFile, actionContent, "utf8")
            filesWritten.push(relative(repoRoot, actionFile))
            actionsGenerated++

            // Generate unit test for action
            const testDir = join(repoRoot, "tests/unit/supabase-data/actions", domainId)
            const testFile = join(
              testDir,
              `${toKebabCase(table)}-${toCamelCase(method)}.codegen.test.ts`
            )
            ensureDir(testFile) // Use ensureDir with file path to create parent dir
            const testContent = generateActionTest(domainId, table, method, actionName)
            writeFileSync(testFile, testContent, "utf8")
            filesWritten.push(relative(repoRoot, testFile))
          }
        }

        if (methods.includes("list")) {
          const queryHookFile = join(hooksDir, `use-${toKebabCase(table)}-query.hook.codegen.ts`)
          const listActionName = `list${toPascalCase(table)}Action`
          const hookName = `use${toPascalCase(table)}Query`

          if (!checkOnly) {
            const hookContent = generateQueryHook(domainId, table, listActionName)
            ensureDir(queryHookFile)
            writeFileSync(queryHookFile, hookContent, "utf8")
            filesWritten.push(relative(repoRoot, queryHookFile))
            hooksGenerated++

            // Generate unit test for query hook
            const testDir = join(repoRoot, "tests/unit/supabase-data/hooks", domainId)
            const testFile = join(testDir, `use-${toKebabCase(table)}-query.hook.codegen.test.ts`)
            ensureDir(testFile) // Use ensureDir with file path to create parent dir
            const testContent = generateHookTest(domainId, table, hookName, "query")
            writeFileSync(testFile, testContent, "utf8")
            filesWritten.push(relative(repoRoot, testFile))
          }
        }

        if (methods.includes("insert")) {
          const mutationHookFile = join(
            hooksDir,
            `use-${toKebabCase(table)}-mutation.hook.codegen.ts`
          )
          const insertActionName = `insert${toPascalCase(table)}Action`
          const hookName = `use${toPascalCase(table)}Mutation`

          if (!checkOnly) {
            const hookContent = generateMutationHook(domainId, table, insertActionName)
            ensureDir(mutationHookFile)
            writeFileSync(mutationHookFile, hookContent, "utf8")
            filesWritten.push(relative(repoRoot, mutationHookFile))
            hooksGenerated++

            // Generate unit test for mutation hook
            const testDir = join(repoRoot, "tests/unit/supabase-data/hooks", domainId)
            const testFile = join(
              testDir,
              `use-${toKebabCase(table)}-mutation.hook.codegen.test.ts`
            )
            ensureDir(testFile) // Use ensureDir with file path to create parent dir
            const testContent = generateHookTest(domainId, table, hookName, "mutation")
            writeFileSync(testFile, testContent, "utf8")
            filesWritten.push(relative(repoRoot, testFile))
          }
        }

        queryKeyTables.push({ tableName: table, methods })
      }

      const queryKeysFile = join(hooksDir, "query-keys.codegen.ts")
      if (!checkOnly && queryKeyTables.length > 0) {
        const queryKeysContent = generateQueryKeys(domainId, queryKeyTables)
        ensureDir(queryKeysFile)
        writeFileSync(queryKeysFile, queryKeysContent, "utf8")
        filesWritten.push(relative(repoRoot, queryKeysFile))
        queryKeysUpdated++
      }
    }

    return {
      ok: true,
      filesWritten,
      errors,
      actionsGenerated,
      hooksGenerated,
      queryKeysUpdated,
    }
  } catch (error) {
    errors.push(error instanceof Error ? error.message : "Unknown error during codegen")
    return {
      ok: false,
      filesWritten,
      errors,
      actionsGenerated,
      hooksGenerated,
      queryKeysUpdated,
    }
  }
}

// CLI Entry Point
if (import.meta.url === `file://${process.argv[1]}`) {
  const argValue = (flag: string): string | undefined => {
    const i = process.argv.indexOf(flag)
    if (i === -1 || !process.argv[i + 1]) {
      return undefined
    }
    return process.argv[i + 1]
  }

  const write = process.argv.includes("--write")
  const checkOnly = process.argv.includes("--check") || !write
  if (write && process.argv.includes("--check")) {
    process.stderr.write("Use either --check or --write, not both\n")
    process.exit(1)
  }

  const repoRoot = resolve(process.cwd())
  const typesPath =
    argValue("--types") ?? resolve(repoRoot, "packages/supabase-infra/src/types/database.types.ts")
  const planPath = resolve(repoRoot, argValue("--plan") ?? "config/repository-plan.json")
  const domainMapPath = resolve(repoRoot, argValue("--map") ?? "config/domain-map.json")
  const domainFilter = argValue("--domain")
  const force = process.argv.includes("--force")

  if (!existsSync(planPath)) {
    process.stderr.write(`Repository plan not found: ${planPath}\n`)
    process.exit(1)
  }

  if (!existsSync(domainMapPath)) {
    process.stderr.write(`Domain map not found: ${domainMapPath}\n`)
    process.exit(1)
  }

  if (!existsSync(typesPath)) {
    process.stderr.write(`Types file not found: ${typesPath}\n`)
    process.exit(1)
  }

  const result = runActionsHooksCodegen({
    repoRoot,
    typesPath,
    planPath,
    domainMapPath,
    checkOnly,
    force,
    domainFilter,
  })

  if (!result.ok) {
    for (const e of result.errors) {
      process.stderr.write(`${e}\n`)
    }
    process.exit(1)
  }

  if (checkOnly) {
    process.stdout.write(
      `codegen:actions-hooks --check OK: ${result.actionsGenerated} actions, ${result.hooksGenerated} hooks, ${result.queryKeysUpdated} query key files would be generated.\n`
    )
  } else if (write && result.filesWritten.length > 0) {
    process.stdout.write(`Generated ${result.filesWritten.length} file(s):\n`)
    for (const f of result.filesWritten) {
      process.stdout.write(`  ${f}\n`)
    }
    process.stdout.write(
      "\nNext steps:\n  1. Add explicit exports in packages/supabase-data/package.json\n  2. Run: pnpm typecheck\n  3. Run: pnpm lint\n  4. Review TODOs in generated files\n"
    )
  } else if (write) {
    process.stdout.write("Nothing to generate.\n")
  }
}
