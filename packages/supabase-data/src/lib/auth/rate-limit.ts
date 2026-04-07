/**
 * Rate limiting for Server Actions
 *
 * Protects PHI-accessing actions from abuse using Upstash Redis + sliding window.
 *
 * ## Why This Exists
 *
 * Supabase rate limiting covers Auth endpoints only (/auth/v1/*). It does NOT
 * cover Server Actions. An attacker with a valid JWT can call PHI-accessing
 * actions thousands of times per minute without restriction.
 *
 * ## Implementation
 *
 * Uses @upstash/ratelimit with sliding window algorithm:
 * - 60 requests per minute per user
 * - Sliding window provides smoother rate limiting than fixed windows
 * - Analytics enabled for monitoring rate limit hits
 *
 * ## Security Properties
 *
 * - Called AFTER identity verification (in requireAuth)
 * - Prevents unauthenticated amplification attacks on the rate limiter itself
 * - Logs all rate limit exceeded events for security audit
 * - Throws on failure — never returns error state
 *
 * @see {@link requireAuth} - Calls this after identity resolution
 * @see {@link https://upstash.com/docs/ratelimit} - Upstash Ratelimit docs
 */
"use server"

import { Ratelimit } from "@upstash/ratelimit"
import { Redis } from "@upstash/redis"

import { logServerEvent } from "@workspace/logging/server"

/**
 * Rate limiter instance
 *
 * Configured for 60 requests per minute per user using sliding window.
 * Sliding window provides smoother rate limiting than fixed windows by
 * calculating rate over a rolling time period.
 */
const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(60, "1 m"), // 60 req/min per user
  analytics: true,
})

/**
 * Check rate limit for user actions
 *
 * Called inside requireAuth() AFTER successful identity verification.
 * Never called before identity check to prevent unauthenticated amplification
 * attacks on the rate limiter itself.
 *
 * @param userId - User ID from JWT claims (claims.sub)
 * @throws Error if rate limit exceeded ("Too Many Requests")
 *
 * @example
 * ```typescript
 * const { userId } = await requireAuth({ action: "list_patients" })
 * // Rate limit already checked in requireAuth
 * ```
 */
export async function checkActionRateLimit(userId: string): Promise<void> {
  const { success, limit, remaining } = await ratelimit.limit(`action:${userId}`)

  if (!success) {
    await logServerEvent({
      actorId: userId,
      actorType: "user",
      component: "auth.rate-limit",
      durationMs: 0,
      eventFamily: "security.audit",
      eventName: "rate_limit_exceeded",
      metadata: {
        limit,
        remaining,
      },
      operation: "checkActionRateLimit",
      operationType: "auth",
      outcome: "failure",
      service: "supabase-data",
    })

    throw new Error("Too Many Requests")
  }
}
