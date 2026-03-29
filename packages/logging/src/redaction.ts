import type { JsonValue } from "@workspace/logging/contracts"

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

function isSensitiveKey(key: string): boolean {
  const normalized = key.trim().toLowerCase()
  return SENSITIVE_KEY_PATTERNS.some((pattern) => normalized.includes(pattern))
}

function truncateString(value: string): string {
  return value.length > 240 ? `${value.slice(0, 237)}...` : value
}

function sanitizeMetadata(value: unknown): JsonValue {
  if (value === null || value === undefined) {
    return null
  }

  if (
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return typeof value === "string" ? truncateString(value) : value
  }

  if (Array.isArray(value)) {
    return value.slice(0, 20).map((entry) => sanitizeMetadata(entry))
  }

  if (value instanceof Date) {
    return value.toISOString()
  }

  if (typeof value === "object") {
    const sanitized: Record<string, JsonValue> = {}

    for (const [key, entry] of Object.entries(value)) {
      sanitized[key] = isSensitiveKey(key)
        ? "[REDACTED]"
        : sanitizeMetadata(entry)
    }

    return sanitized
  }

  return String(value)
}

async function hashDeterministic(
  value: string | null | undefined
): Promise<string | null> {
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
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(normalized)
  )

  return Array.from(new Uint8Array(signature), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("")
}

function getHashSecret(): string {
  const configured = process.env.OBSERVABILITY_HASH_SECRET?.trim()
  if (configured) {
    return configured
  }

  const isProductionLike =
    process.env.NODE_ENV === "production" || Boolean(process.env.VERCEL)

  if (isProductionLike) {
    throw new Error(
      "Missing OBSERVABILITY_HASH_SECRET for production observability hashing."
    )
  }

  return "template-local-observability-dev-secret"
}

function getIpAddressFromHeaders(headers: Headers): string | null {
  const forwardedFor = headers.get("x-forwarded-for")
  if (forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() ?? null
  }

  return headers.get("x-real-ip")?.trim() ?? null
}

function sanitizeRequestPath(path: string | null | undefined): string | null {
  if (!path) {
    return null
  }

  try {
    if (path.startsWith("http://") || path.startsWith("https://")) {
      return new URL(path).pathname
    }
  } catch {
    return truncateString(path)
  }

  return truncateString(path.split("?")[0] ?? path)
}

export {
  getIpAddressFromHeaders,
  hashDeterministic,
  sanitizeMetadata,
  sanitizeRequestPath,
}
