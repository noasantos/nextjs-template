/**
 * Metadata redaction and sanitization
 *
 * Provides utilities for redacting sensitive data from logs
 * to prevent security leaks.
 *
 * ## Security
 *
 * This package automatically redacts:
 * - 🔒 Authorization headers
 * - 🔒 Cookies
 * - 🔒 Tokens (JWT, API tokens)
 * - 🔒 Secrets
 * - 🔒 Passwords
 * - 🔒 OTP codes
 * - 🔒 Email addresses
 * - 🔒 Phone numbers
 * - 🔒 Full names
 *
 * ## Usage
 *
 * ```typescript
 * import { sanitizeMetadata, hashDeterministic } from "@workspace/logging/redaction"
 *
 * const metadata = {
 *   userId: "user-123",
 *   email: "user@example.com", // Will be redacted
 *   token: "secret-token",     // Will be redacted
 *   action: "login",           // Will NOT be redacted
 * }
 *
 * const sanitized = sanitizeMetadata(metadata)
 * // Result: {
 * //   userId: "user-123",
 * //   email: "[REDACTED]",
 * //   token: "[REDACTED]",
 * //   action: "login"
 * // }
 * ```
 *
 * ## Hashing PII
 *
 * For user IDs and emails that need to be tracked (but anonymized):
 *
 * ```typescript
 * const userIdHash = await hashDeterministic("user-123")
 * // Returns: "a1b2c3d4..." (SHA-256 hash)
 * ```
 *
 * @module @workspace/logging/redaction
 */
import type { JsonValue } from "./contracts"

/**
 * Sensitive key patterns to redact
 */
const SENSITIVE_KEY_PATTERNS = [
  "authorization",
  "cookie",
  "token",
  "secret",
  "password",
  "otp",
  "email",
  "phone",
  "full_name",
  "fullName",
  "jwt",
  "service_role",
] as const

/**
 * Check if key is sensitive
 *
 * @param key - Object key to check
 * @returns True if key should be redacted
 */
export function isSensitiveKey(key: string): boolean {
  const normalized = key.trim().toLowerCase()
  return SENSITIVE_KEY_PATTERNS.some((pattern) => normalized.includes(pattern))
}

/**
 * Truncate string to max length
 *
 * @param value - String to truncate
 * @param maxLength - Max length (default: 240)
 * @returns Truncated string
 */
export function truncateString(value: string, maxLength = 240): string {
  return value.length > maxLength ? `${value.slice(0, maxLength - 3)}...` : value
}

/**
 * Sanitize metadata for logging
 *
 * Recursively sanitizes object, redacting sensitive values
 * and truncating strings.
 *
 * @param value - Value to sanitize
 * @returns Sanitized JSON value
 */
export function sanitizeMetadata(value: unknown): JsonValue {
  if (value === null || value === undefined) {
    return null
  }

  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") {
    return typeof value === "string" ? truncateString(value) : value
  }

  if (Array.isArray(value)) {
    // Limit array size to prevent log flooding
    return value.slice(0, 20).map((entry) => sanitizeMetadata(entry))
  }

  if (value instanceof Date) {
    return value.toISOString()
  }

  if (typeof value === "object") {
    const sanitized: Record<string, JsonValue> = {}

    for (const [key, entry] of Object.entries(value)) {
      // Redact sensitive keys
      sanitized[key] = isSensitiveKey(key) ? "[REDACTED]" : sanitizeMetadata(entry)
    }

    return sanitized
  }

  return String(value)
}

/**
 * Hash value deterministically
 *
 * Uses HMAC-SHA256 with secret key for consistent hashing.
 * Used for anonymizing user IDs and emails while maintaining
 * ability to track across sessions.
 *
 * @param value - Value to hash
 * @returns Hex string of hash
 */
export async function hashDeterministic(value: string | null | undefined): Promise<string | null> {
  const normalized = value?.trim()
  if (!normalized) {
    return null
  }

  const secret = getHashSecret()
  const encoder = new TextEncoder()
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { hash: "SHA-256", name: "HMAC" },
    false,
    ["sign"]
  )
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(normalized))

  return Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join(
    ""
  )
}

/**
 * Get hash secret from environment
 *
 * @returns Secret key for hashing
 * @throws Error if missing in production
 */
function getHashSecret(): string {
  const configured = process.env.OBSERVABILITY_HASH_SECRET?.trim()
  if (configured) {
    return configured
  }

  const isProductionLike = process.env.NODE_ENV === "production" || Boolean(process.env.VERCEL)

  if (isProductionLike) {
    throw new Error(
      "Missing OBSERVABILITY_HASH_SECRET for production observability hashing. " +
        "Set this environment variable before deploying."
    )
  }

  // Development fallback
  return "template-local-observability-dev-secret"
}

/**
 * Get IP address from headers
 *
 * Extracts client IP from standard proxy headers.
 *
 * @param headers - Request headers
 * @returns IP address or null
 */
export function getIpAddressFromHeaders(headers: Headers): string | null {
  const forwardedFor = headers.get("x-forwarded-for")
  if (forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() ?? null
  }

  return headers.get("x-real-ip")?.trim() ?? null
}

/**
 * Sanitize request path
 *
 * Extracts pathname from URL and truncates if needed.
 *
 * @param path - URL or path string
 * @returns Sanitized path or null
 */
export function sanitizeRequestPath(path: string | null | undefined): string | null {
  if (!path) {
    return null
  }

  try {
    // If full URL, extract pathname
    if (path.startsWith("http://") || path.startsWith("https://")) {
      return new URL(path).pathname
    }
  } catch {
    return truncateString(path)
  }

  // Remove query string
  return truncateString(path.split("?")[0] ?? path)
}
