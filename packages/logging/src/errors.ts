import type { ErrorCategory } from "@workspace/logging/contracts"

type SerializableError = {
  category: ErrorCategory
  code: string | null
  message: string
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message.trim().slice(0, 240)
  }

  if (
    error &&
    typeof error === "object" &&
    typeof Reflect.get(error, "message") === "string"
  ) {
    return String(Reflect.get(error, "message")).trim().slice(0, 240)
  }

  if (typeof error === "string" && error.trim()) {
    return error.trim().slice(0, 240)
  }

  return "Unknown error"
}

function getErrorCode(error: unknown): string | null {
  if (!error || typeof error !== "object") {
    return null
  }

  const candidate = Reflect.get(error, "code")
  if (typeof candidate === "string" || typeof candidate === "number") {
    return String(candidate)
  }

  const name = Reflect.get(error, "name")
  if (typeof name === "string" && name.trim()) {
    return name.trim()
  }

  const status = Reflect.get(error, "status")
  if (typeof status === "number") {
    return String(status)
  }

  return null
}

function categorizeError(error: unknown): ErrorCategory {
  if (!error || typeof error !== "object") {
    return "unknown"
  }

  const code = getErrorCode(error)
  const message = getErrorMessage(error).toLowerCase()
  const name =
    typeof Reflect.get(error, "name") === "string"
      ? String(Reflect.get(error, "name")).toLowerCase()
      : ""

  if (code === "PGRST116" || message.includes("not found")) {
    return "not_found"
  }

  if (code === "23503" || code === "23505" || message.includes("postgres")) {
    return "database"
  }

  if (
    message.includes("rls") ||
    message.includes("row level security") ||
    message.includes("permission denied")
  ) {
    return "supabase_rls"
  }

  if (
    message.includes("invalid") ||
    message.includes("validation") ||
    message.includes("schema")
  ) {
    return "validation"
  }

  if (
    message.includes("unauthorized") ||
    message.includes("forbidden") ||
    message.includes("permission")
  ) {
    return "authorization"
  }

  if (
    message.includes("auth") ||
    name.includes("auth") ||
    message.includes("otp")
  ) {
    return "supabase_auth"
  }

  if (
    message.includes("fetch") ||
    message.includes("network") ||
    message.includes("timeout")
  ) {
    return "network"
  }

  if (message.includes("conflict")) {
    return "conflict"
  }

  if (message.includes("database") || message.includes("rpc")) {
    return "database"
  }

  if (message.includes("integration") || message.includes("provider")) {
    return "integration"
  }

  return "unknown"
}

function serializeUnknownError(error: unknown): SerializableError {
  return {
    category: categorizeError(error),
    code: getErrorCode(error),
    message: getErrorMessage(error),
  }
}

export { categorizeError, serializeUnknownError }
export type { SerializableError }
