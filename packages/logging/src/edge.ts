/**
 * Edge runtime logging for Supabase Edge Functions
 *
 * This is the **ONLY** approved way to log in Edge Functions.
 * Provides the SAME rich, contextual logging as server-side.
 *
 * ## Architecture
 *
 * Edge logging sends structured events to a logging endpoint
 * which processes and stores them with full context:
 *
 * ```
 * Edge Function
 *      ↓
 * logEdgeEvent() - Full context (correlation, IP, user agent, etc.)
 *      ↓
 * POST /api/log (or direct to Supabase)
 *      ↓
 * Server receives and stores in observability_events table
 * ```
 *
 * ## When to Use
 *
 * **Use edge logging in:**
 * - ✅ Supabase Edge Functions (`supabase/functions/`)
 * - ✅ Vercel Edge Middleware
 * - ✅ Cloudflare Workers
 *
 * **Do NOT use in:**
 * - ❌ Node.js server code (use logServerEvent)
 * - ❌ Browser code (use logClientEvent)
 *
 * ## Usage
 *
 * ```typescript
 * // supabase/functions/my-function/index.ts
 * import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
 * import { logEdgeEvent } from "@workspace/logging/edge"
 *
 * serve(async (req) => {
 *   const startedAt = Date.now()
 *   const traceId = req.headers.get("x-trace-id") || crypto.randomUUID()
 *
 *   try {
 *     // ... function logic
 *
 *     await logEdgeEvent(req, {
 *       component: "my-function",
 *       eventFamily: "edge.request",
 *       eventName: "function_executed",
 *       outcome: "success",
 *       durationMs: Date.now() - startedAt,
 *       metadata: {
 *         functionName: "my-function",
 *         environment: Deno.env.get("DENO_DEPLOYMENT_ID") ? "production" : "development",
 *       },
 *     })
 *
 *     return new Response(JSON.stringify({ success: true }))
 *   } catch (error) {
 *     await logEdgeEvent(req, {
 *       component: "my-function",
 *       eventFamily: "edge.request",
 *       eventName: "function_failed",
 *       outcome: "failure",
 *       error,
 *       durationMs: Date.now() - startedAt,
 *       metadata: {
 *         functionName: "my-function",
 *         errorType: error.constructor.name,
 *       },
 *     })
 *
 *     return new Response(JSON.stringify({ error: "Failed" }), { status: 500 })
 *   }
 * })
 * ```
 *
 * ## Rich Context
 *
 * Edge logging includes FULL context (same as server):
 *
 * - ✅ **Correlation ID** - Request tracing across services
 * - ✅ **Trace ID** - Distributed tracing (W3C traceparent)
 * - ✅ **IP Hash** - Anonymized user tracking
 * - ✅ **User Agent** - Client information
 * - ✅ **Request Path** - Endpoint called
 * - ✅ **Environment** - Production/development
 * - ✅ **Duration** - Performance metrics
 * - ✅ **Error Details** - Categorized and serialized
 * - ✅ **Metadata** - Rich contextual data (redacted)
 *
 * @see {@link logServerEvent} - Node.js server logging (same richness)
 * @see {@link logClientEvent} - Browser logging
 *
 * @module @workspace/logging/edge
 */
import type { EventFamily, Outcome, OperationType, Severity, ObservabilityEvent } from "./contracts"
import { ObservabilityEventSchema } from "./contracts"
import { serializeUnknownError, getErrorMessage, getErrorCode } from "./errors"

/**
 * Edge event input - same structure as server for consistency
 */
export interface EdgeEventInput {
  actorId?: string | null
  actorType?: "anonymous" | "user" | "service" | "system" | "admin" | "unknown"
  component: string
  durationMs?: number | null
  error?: unknown
  eventFamily: EventFamily
  eventName: string
  httpStatus?: number | null
  metadata?: Record<string, unknown>
  operation: string
  operationType?: OperationType
  outcome: Outcome
  requestPath?: string | null
  role?: string | null
  severity?: Severity
}

/**
 * Extract correlation context from request headers
 *
 * Follows W3C traceparent format for distributed tracing.
 *
 * @param request - Edge request
 * @returns Correlation context
 */
function extractCorrelationFromRequest(request: Request): {
  correlationId: string
  correlationProvenance: "generated" | "inherited"
  traceId: string
} {
  const inheritedTraceId =
    request.headers.get("x-trace-id") ||
    extractTraceIdFromTraceparent(request.headers.get("traceparent"))
  const inheritedCorrelationId = request.headers.get("x-correlation-id")

  if (inheritedTraceId && inheritedCorrelationId) {
    return {
      correlationId: inheritedCorrelationId,
      correlationProvenance: "inherited",
      traceId: inheritedTraceId,
    }
  }

  // Generate new correlation context
  return {
    correlationId: crypto.randomUUID(),
    correlationProvenance: "generated",
    traceId: crypto.randomUUID(),
  }
}

/**
 * Extract trace ID from W3C traceparent header
 *
 * Format: 00-<32-char-trace-id>-<16-char-span-id>-<2-char-flags>
 */
function extractTraceIdFromTraceparent(value: string | null): string | null {
  if (!value) return null

  const match = value.match(/^[\da-f]{2}-([\da-f]{32})-[\da-f]{16}-[\da-f]{2}$/i)
  return match?.[1] ?? null
}

/**
 * Get IP address from request headers
 *
 * Prioritizes standard proxy headers.
 */
function getIpAddressFromRequest(request: Request): string | null {
  const forwardedFor = request.headers.get("x-forwarded-for")
  if (forwardedFor) {
    return forwardedFor.split(",")[0]?.trim() ?? null
  }

  return request.headers.get("x-real-ip")?.trim() ?? null
}

/**
 * Hash value deterministically using SHA-256
 *
 * Used for anonymizing user IDs and emails.
 */
async function hashDeterministic(value: string | null | undefined): Promise<string | null> {
  const normalized = value?.trim()
  if (!normalized) {
    return null
  }

  const encoder = new TextEncoder()
  const data = encoder.encode(normalized)
  const hashBuffer = await crypto.subtle.digest("SHA-256", data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))

  return hashArray.map((byte) => byte.toString(16).padStart(2, "0")).join("")
}

/**
 * Sanitize metadata for logging
 *
 * Redacts sensitive fields and truncates strings.
 */
function sanitizeMetadata(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null) {
    return {}
  }

  const sensitiveKeys = [
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
  ]

  const sanitized: Record<string, unknown> = {}

  for (const [key, val] of Object.entries(value)) {
    // Redact sensitive keys
    if (sensitiveKeys.some((pattern) => key.toLowerCase().includes(pattern))) {
      sanitized[key] = "[REDACTED]"
    } else if (typeof val === "string") {
      // Truncate long strings
      sanitized[key] = val.length > 240 ? `${val.slice(0, 237)}...` : val
    } else if (typeof val === "object" && val !== null) {
      // Recursively sanitize nested objects
      sanitized[key] = sanitizeMetadata(val)
    } else {
      sanitized[key] = val
    }
  }

  return sanitized
}

/**
 * Get environment name from Deno
 */
function getEnvironmentName(): string {
  const deploymentId = Deno.env.get("DENO_DEPLOYMENT_ID")
  if (deploymentId) {
    return "production"
  }

  return Deno.env.get("DENO_ENV") || "development"
}

/**
 * Log event from Edge Function
 *
 * Sends RICH, STRUCTURED log to Supabase observability_events table.
 * Includes full context: correlation ID, IP hash, user agent, duration, etc.
 *
 * @param request - Original request object
 * @param input - Event details
 * @returns Promise that resolves when logged
 */
export async function logEdgeEvent(request: Request, input: EdgeEventInput): Promise<void> {
  const startedAt = Date.now()

  try {
    // Extract full context (same as server)
    const correlation = extractCorrelationFromRequest(request)
    const ipAddress = getIpAddressFromRequest(request)
    const userAgent = request.headers.get("user-agent")
    const requestPath = new URL(request.url).pathname
    const environment = getEnvironmentName()

    // Serialize error if present
    const error = input.error ? serializeUnknownError(input.error) : null

    // Build full observability event (same structure as server)
    const event: ObservabilityEvent = {
      actor_id_hash: input.actorId ? await hashDeterministic(input.actorId) : null,
      actor_type: input.actorType ?? "unknown",
      component: input.component,
      correlation_id: correlation.correlationId,
      correlation_provenance: correlation.correlationProvenance,
      duration_ms: input.durationMs ?? Date.now() - startedAt,
      environment: environment,
      error_category: error?.category ?? null,
      error_code: error?.code ?? null,
      error_message: error?.message ?? null,
      event_family: input.eventFamily,
      event_name: input.eventName,
      http_status: input.httpStatus ?? null,
      ip_hash: ipAddress ? await hashDeterministic(ipAddress) : null,
      metadata: sanitizeMetadata(input.metadata ?? {}),
      operation: input.operation,
      operation_type: input.operationType ?? "edge",
      outcome: input.outcome,
      persisted: false,
      request_path: input.requestPath ?? requestPath,
      role: input.role ?? null,
      runtime: "edge",
      service: input.component,
      severity: input.severity ?? (input.outcome === "failure" ? "error" : "info"),
      timestamp: new Date().toISOString(),
      trace_id: correlation.traceId,
      user_agent: userAgent,
    }

    // Validate event schema
    const validatedEvent = ObservabilityEventSchema.parse(event)

    // Send to logging endpoint (or directly to Supabase in production)
    const loggingEndpoint = Deno.env.get("LOGGING_ENDPOINT") || "https://your-api.com/api/log"

    await fetch(loggingEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-trace-id": validatedEvent.trace_id,
        "x-correlation-id": validatedEvent.correlation_id,
      },
      body: JSON.stringify(validatedEvent),
    })
  } catch (error) {
    // Fallback to console.error in edge runtime (should never happen)
    const errorMessage = getErrorMessage(error)
    console.error(`[EdgeLogger] Failed to send log: ${errorMessage}`)
  }
}

/**
 * Log edge error helper
 *
 * Simplifies error logging with proper defaults.
 *
 * @param request - Original request
 * @param error - Error object
 * @param component - Component where error occurred
 * @param metadata - Additional context
 */
export async function logEdgeError(
  request: Request,
  error: unknown,
  component: string,
  metadata?: Record<string, unknown>
): Promise<void> {
  await logEdgeEvent(request, {
    component,
    eventFamily: "edge.request",
    eventName: "edge_error",
    outcome: "failure",
    error,
    severity: "error",
    operation: "error",
    metadata: {
      ...metadata,
      errorType: error instanceof Error ? error.constructor.name : "Unknown",
      errorMessage: getErrorMessage(error),
      errorCode: getErrorCode(error),
    },
  })
}

/**
 * Log edge request start
 *
 * Useful for tracking long-running operations.
 *
 * @param request - Original request
 * @param eventName - Event name
 * @param metadata - Additional context
 */
export async function logEdgeRequestStart(
  request: Request,
  eventName: string,
  metadata?: Record<string, unknown> | undefined
): Promise<void> {
  await logEdgeEvent(request, {
    component: new URL(request.url).pathname,
    eventFamily: "edge.request",
    eventName: `${eventName}_start`,
    outcome: "success",
    operation: eventName,
    operationType: "http",
    severity: "info",
    ...(metadata && { metadata }),
  })
}

/**
 * Log edge request complete
 *
 * @param request - Original request
 * @param eventName - Event name
 * @param durationMs - Operation duration
 * @param metadata - Additional context
 */
export async function logEdgeRequestComplete(
  request: Request,
  eventName: string,
  durationMs: number,
  metadata?: Record<string, unknown> | undefined
): Promise<void> {
  await logEdgeEvent(request, {
    component: new URL(request.url).pathname,
    eventFamily: "edge.request",
    eventName: `${eventName}_complete`,
    outcome: "success",
    operation: eventName,
    operationType: "http",
    severity: "info",
    durationMs,
    ...(metadata && { metadata }),
  })
}
