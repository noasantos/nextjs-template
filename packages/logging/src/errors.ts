/**
 * Error categorization and serialization
 *
 * Provides utilities for categorizing and serializing errors
 * for structured logging.
 *
 * ## Usage
 *
 * ```typescript
 * import { categorizeError, serializeUnknownError } from "@workspace/logging/errors"
 *
 * try {
 *   // ... operation
 * } catch (error) {
 *   const serialized = serializeUnknownError(error)
 *
 *   console.log({
 *     category: serialized.category, // "validation", "auth", "database", etc.
 *     code: serialized.code,         // Error code if available
 *     message: serialized.message,   // Human-readable message
 *   })
 * }
 * ```
 *
 * ## Error Categories
 *
 * | Category | When Used |
 * |----------|-----------|
 * | `validation` | Input validation failures (Zod errors) |
 * | `authentication` | Auth failures (invalid credentials) |
 * | `authorization` | Permission denials (RLS, guards) |
 * | `business` | Business rule violations |
 * | `not_found` | Resource not found (404) |
 * | `conflict` | Conflicts (duplicate key, optimistic lock) |
 * | `database` | Postgres/Supabase errors |
 * | `supabase_auth` | Supabase Auth errors |
 * | `supabase_rls` | RLS policy violations |
 * | `integration` | Third-party API failures |
 * | `network` | Network errors (timeout, connection) |
 * | `unknown` | Unclassified errors |
 *
 * @module @workspace/logging/errors
 */
import type { ErrorCategory } from "./contracts"

/**
 * Serializable error structure
 */
export type SerializableError = {
  category: ErrorCategory
  code: string | null
  message: string
}

/**
 * Get error message from unknown error type
 *
 * Handles Error objects, objects with message property, and strings.
 * Truncates to 240 characters max.
 *
 * @param error - Unknown error object
 * @returns Error message string
 */
export function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message.trim().slice(0, 240)
  }

  if (error && typeof error === "object" && typeof Reflect.get(error, "message") === "string") {
    return String(Reflect.get(error, "message")).trim().slice(0, 240)
  }

  if (typeof error === "string" && error.trim()) {
    return error.trim().slice(0, 240)
  }

  return "Unknown error"
}

/**
 * Get error code from unknown error type
 *
 * Extracts code, name, or status from error object.
 *
 * @param error - Unknown error object
 * @returns Error code or null
 */
export function getErrorCode(error: unknown): string | null {
  if (!error || typeof error !== "object") {
    return null
  }

  // Try to get error code
  const candidate = Reflect.get(error, "code")
  if (typeof candidate === "string" || typeof candidate === "number") {
    return String(candidate)
  }

  // Try to get error name
  const name = Reflect.get(error, "name")
  if (typeof name === "string" && name.trim()) {
    return name.trim()
  }

  // Try to get HTTP status
  const status = Reflect.get(error, "status")
  if (typeof status === "number") {
    return String(status)
  }

  return null
}

/**
 * Categorize error by type
 *
 * Analyzes error message, code, and name to determine category.
 * Uses pattern matching for common error types.
 *
 * @param error - Unknown error object
 * @returns Error category
 */
export function categorizeError(error: unknown): ErrorCategory {
  if (!error || typeof error !== "object") {
    return "unknown"
  }

  const code = getErrorCode(error)
  const message = getErrorMessage(error).toLowerCase()
  const name =
    typeof Reflect.get(error, "name") === "string"
      ? String(Reflect.get(error, "name")).toLowerCase()
      : ""

  // Not found errors
  if (code === "PGRST116" || message.includes("not found")) {
    return "not_found"
  }

  // Database errors
  if (code === "23503" || code === "23505" || message.includes("postgres")) {
    return "database"
  }

  // RLS errors
  if (
    message.includes("rls") ||
    message.includes("row level security") ||
    message.includes("permission denied")
  ) {
    return "supabase_rls"
  }

  // Validation errors
  if (
    message.includes("invalid") ||
    message.includes("validation") ||
    message.includes("schema") ||
    name.includes("zod")
  ) {
    return "validation"
  }

  // Authorization errors
  if (
    message.includes("unauthorized") ||
    message.includes("forbidden") ||
    message.includes("permission")
  ) {
    return "authorization"
  }

  // Auth errors
  if (message.includes("auth") || name.includes("auth") || message.includes("otp")) {
    return "supabase_auth"
  }

  // Network errors
  if (message.includes("fetch") || message.includes("network") || message.includes("timeout")) {
    return "network"
  }

  // Conflict errors
  if (message.includes("conflict")) {
    return "conflict"
  }

  // Integration errors
  if (message.includes("integration") || message.includes("provider")) {
    return "integration"
  }

  return "unknown"
}

/**
 * Serialize unknown error to structured format
 *
 * Converts any error to SerializableError with category, code, and message.
 *
 * @param error - Unknown error object
 * @returns Serializable error
 */
export function serializeUnknownError(error: unknown): SerializableError {
  return {
    category: categorizeError(error),
    code: getErrorCode(error),
    message: getErrorMessage(error),
  }
}
