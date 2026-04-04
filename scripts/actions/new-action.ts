#!/usr/bin/env tsx
/**
 * Server Action Template Generator
 *
 * This script generates a new Server Action with proper logging,
 * error handling, and type safety already configured.
 *
 * Usage:
 *   pnpm action:new -- <module> <action-name>
 *
 * Example:
 *   pnpm action:new -- tasks create-task
 *
 * Output:
 *   Creates packages/supabase-data/src/actions/tasks/create-task.ts
 *   with complete template including logging.
 */

import { writeFileSync, mkdirSync, existsSync } from "node:fs"
import { join } from "node:path"

// Parse arguments
const args = process.argv.slice(2)
const [moduleName, actionName] = args

if (!moduleName || !actionName) {
  console.error("Usage: pnpm action:new -- <module> <action-name>")
  console.error("Example: pnpm action:new -- tasks create-task")
  process.exit(1)
}

// Convert to PascalCase for component names
const toPascalCase = (str: string): string =>
  str.replace(/(\w)(\w*)/g, (_, i, r) => i.toUpperCase() + r.toLowerCase())

const actionNamePascal = toPascalCase(actionName)
const inputTypeName = `${actionNamePascal}Input`
const outputTypeName = `${actionNamePascal}Output`

// Create directory if not exists
const actionsDir = join(process.cwd(), "packages/supabase-data/src/actions", moduleName)
if (!existsSync(actionsDir)) {
  mkdirSync(actionsDir, { recursive: true })
  console.log(`✅ Created directory: ${actionsDir}`)
}

// Generate Server Action template
const template = `/**
 * ${actionNamePascal} Server Action
 * 
 * Handles ${actionName.replace(/-/g, " ")} with proper logging and error handling.
 * 
 * ## Usage
 * 
 * \`\`\`typescript
 * import { ${actionName}Action } from "@workspace/supabase-data/actions/${moduleName}/${actionName}"
 * 
 * const result = await ${actionName}Action({ /* input */ })
 * if (result.success) {
 *   console.log("Success:", result.data)
 * } else {
 *   console.error("Error:", result.error)
 * }
 * \`\`\`
 * 
 * @module @workspace/supabase-data/actions/${moduleName}/${actionName}
 */
"use server"

import { z } from "zod"

import { logServerEvent } from "@workspace/logging/server"
import { createServerAuthClient } from "@workspace/supabase-auth/server/create-server-auth-client"
import { getClaims } from "@workspace/supabase-auth/session/get-claims"
import { ${moduleName === "tasks" ? "TaskSupabaseRepository" : `${toPascalCase(moduleName)}SupabaseRepository`} } from "@workspace/supabase-data/modules/${moduleName}/infrastructure/repositories/${moduleName}-supabase.repository"
import { AppError } from "@workspace/supabase-data/lib/errors/app-error"
import { ok, err } from "@workspace/supabase-data/lib/boundary/result"
import { serializeResult } from "@workspace/supabase-data/lib/boundary/serialize-result"
import type { ActionResult } from "@workspace/supabase-data/lib/boundary/action-result"

/**
 * Input schema for ${actionName} action
 */
const ${actionNamePascal}InputSchema = z.object({
  // TODO: Define your input fields
  // Example:
  // title: z.string().min(1, "Title is required"),
  // description: z.string().min(10, "Description must be at least 10 characters"),
})

/**
 * Input type for ${actionName} action
 */
export type ${inputTypeName} = z.infer<typeof ${actionNamePascal}InputSchema>

/**
 * Output type for ${actionName} action
 */
export type ${outputTypeName} = {
  // TODO: Define your output fields
  // Example:
  // id: string
  // createdAt: string
}

/**
 * ${actionNamePascal} Server Action
 * 
 * @param input - Action input
 * @returns Action result with ${outputTypeName} or error
 */
export async function ${actionName}Action(
  input: ${inputTypeName}
): Promise<ActionResult<${outputTypeName}>> {
  const startedAt = Date.now()
  const claims = await getClaims()

  // Authentication check
  if (!claims?.sub) {
    await logServerEvent({
      component: "${moduleName}.${actionName}",
      eventFamily: "security.audit",
      eventName: "${actionName}_unauthorized",
      outcome: "failure",
      service: "supabase-data",
    })
    return serializeResult(err(AppError.auth("Unauthorized")))
  }

  const userId = claims.sub

  try {
    // Validate input
    const validated = ${actionNamePascal}InputSchema.parse(input)

    // Create repository and execute operation
    const supabase = await createServerAuthClient()
    const repository = new ${moduleName === "tasks" ? "TaskSupabaseRepository" : `${toPascalCase(moduleName)}SupabaseRepository`}(supabase)
    
    // TODO: Implement your business logic here
    // Example:
    // const result = await repository.create({
    //   ...validated,
    //   userId,
    // })

    // Log success
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "${moduleName}.${actionName}",
      eventFamily: "action.lifecycle",
      eventName: "${actionName}_success",
      outcome: "success",
      durationMs: Date.now() - startedAt,
      metadata: {
        // TODO: Add relevant metadata
        // Example:
        // itemId: result.id,
      },
      service: "supabase-data",
    })

    // TODO: Return your result
    return serializeResult(ok({
      // TODO: Return data
      // Example:
      // id: result.id,
      // createdAt: result.createdAt,
    } as ${outputTypeName}))
  } catch (error) {
    // Log error
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "${moduleName}.${actionName}",
      eventFamily: "action.lifecycle",
      eventName: "${actionName}_failed",
      outcome: "failure",
      error,
      durationMs: Date.now() - startedAt,
      metadata: {
        input: JSON.stringify(input),
      },
      service: "supabase-data",
    })

    // Convert to AppError and return
    if (error instanceof z.ZodError) {
      return serializeResult(err(AppError.validation("Invalid input", {
        fieldErrors: error.flatten().fieldErrors as Record<string, string[]>,
      })))
    }

    return serializeResult(err(AppError.infra("Failed to ${actionName.replace(/-/g, " ")}", { cause: error })))
  }
}
`

// Write file
const filePath = join(actionsDir, `${actionName}.ts`)
writeFileSync(filePath, template, "utf-8")

console.log(`✅ Created Server Action: ${filePath}`)
console.log("")
console.log("📝 Next steps:")
console.log("  1. Define input schema (replace TODO comments)")
console.log("  2. Implement business logic")
console.log("  3. Define output type")
console.log("  4. Add metadata to logging calls")
console.log("  5. Run: pnpm test to create tests")
console.log("")
console.log("📖 See docs/standards/golden-rules.md for guidelines")
