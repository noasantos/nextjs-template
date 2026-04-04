import "server-only"

type SensitiveAuthRouteKey = "auth_callback" | "auth_confirm"

type SensitiveRouteFailureReason = "rate_limited" | "abuse_protection_required"

type SensitiveRouteDecision =
  | {
      ok: true
    }
  | {
      key: SensitiveAuthRouteKey
      ok: false
      reason: SensitiveRouteFailureReason
      retryAfterSeconds: number
    }

type SensitiveRouteProtectionContext = {
  headers: Headers
  key: SensitiveAuthRouteKey
}

type SensitiveRouteProtector = (
  context: SensitiveRouteProtectionContext
) => Promise<SensitiveRouteDecision> | SensitiveRouteDecision

type MemoryWindowState = {
  count: number
  resetAt: number
}

const DEFAULT_WINDOW_MS = 60_000

const DEFAULT_LIMITS: Record<SensitiveAuthRouteKey, number> = {
  auth_callback: 12,
  auth_confirm: 12,
}

/**
 * Client IP for abuse bucketing. Prefer platform-set headers (harder to spoof from the
 * browser) when present; see docs/guides/auth-invariants.md.
 */
function getClientAddress(headers: Headers) {
  const cf = headers.get("cf-connecting-ip")?.trim()
  if (cf) {
    return cf
  }

  const vercelForwarded = headers.get("x-vercel-forwarded-for")?.trim()
  if (vercelForwarded) {
    return vercelForwarded.split(",")[0]?.trim() ?? "unknown"
  }

  const realIp = headers.get("x-real-ip")?.trim()
  if (realIp) {
    return realIp
  }

  const forwardedFor = headers.get("x-forwarded-for")
  if (forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() ?? "unknown"
  }

  return "unknown"
}

function getMemoryKey({ headers, key }: SensitiveRouteProtectionContext): string {
  return `${key}:${getClientAddress(headers)}`
}

function createMemorySensitiveRouteProtector(): SensitiveRouteProtector {
  const memoryRouteWindows = new Map<string, MemoryWindowState>()

  return ({ headers, key }) => {
    const now = Date.now()
    const memoryKey = getMemoryKey({ headers, key })
    const current = memoryRouteWindows.get(memoryKey)

    if (!current || current.resetAt <= now) {
      memoryRouteWindows.set(memoryKey, {
        count: 1,
        resetAt: now + DEFAULT_WINDOW_MS,
      })
      return { ok: true }
    }

    if (current.count >= DEFAULT_LIMITS[key]) {
      return {
        key,
        ok: false,
        reason: "rate_limited",
        retryAfterSeconds: Math.max(1, Math.ceil((current.resetAt - now) / 1000)),
      }
    }

    current.count += 1
    memoryRouteWindows.set(memoryKey, current)
    return { ok: true }
  }
}

const passThroughProtector: SensitiveRouteProtector = async () => ({ ok: true })

const FAIL_CLOSED_RETRY_AFTER_SECONDS = 120

const failClosedProtector: SensitiveRouteProtector = async ({ key }) => ({
  key,
  ok: false,
  reason: "abuse_protection_required",
  retryAfterSeconds: FAIL_CLOSED_RETRY_AFTER_SECONDS,
})

let memoryProtectorSingleton: SensitiveRouteProtector | undefined

function getMemoryProtectorSingleton(): SensitiveRouteProtector {
  if (!memoryProtectorSingleton) {
    memoryProtectorSingleton = createMemorySensitiveRouteProtector()
  }
  return memoryProtectorSingleton
}

let protectorCacheKey = ""
let cachedResolvedProtector: SensitiveRouteProtector | undefined

/**
 * Resolves the active protector from env on first use and whenever
 * `AUTH_RATE_LIMIT_MODE` or `NODE_ENV` changes (supports tests and rare runtime toggles).
 *
 * - `AUTH_RATE_LIMIT_MODE=off` — pass-through (documented dangerous; not for production).
 * - `AUTH_RATE_LIMIT_MODE=memory` — in-process windowed limits (single-instance / dev only).
 * - `NODE_ENV=production` without `memory` — fail closed (503) until a durable limiter is wired.
 * - Non-production — memory limiter by default for safe local and test runs.
 */
function resolveSensitiveRouteProtector(): SensitiveRouteProtector {
  const mode = process.env.AUTH_RATE_LIMIT_MODE?.trim()
  const nodeEnv = process.env.NODE_ENV ?? ""
  const cacheKey = `${mode}|${nodeEnv}`

  if (cacheKey === protectorCacheKey && cachedResolvedProtector) {
    return cachedResolvedProtector
  }

  protectorCacheKey = cacheKey

  if (mode === "off") {
    cachedResolvedProtector = passThroughProtector
    return cachedResolvedProtector
  }

  if (mode === "memory") {
    cachedResolvedProtector = getMemoryProtectorSingleton()
    return cachedResolvedProtector
  }

  if (nodeEnv === "production") {
    cachedResolvedProtector = failClosedProtector
    return cachedResolvedProtector
  }

  cachedResolvedProtector = getMemoryProtectorSingleton()
  return cachedResolvedProtector
}

async function protectSensitiveAuthRoute(context: SensitiveRouteProtectionContext) {
  return resolveSensitiveRouteProtector()(context)
}

export {
  createMemorySensitiveRouteProtector,
  protectSensitiveAuthRoute,
  type SensitiveAuthRouteKey,
  type SensitiveRouteDecision,
  type SensitiveRouteFailureReason,
  type SensitiveRouteProtectionContext,
  type SensitiveRouteProtector,
}
