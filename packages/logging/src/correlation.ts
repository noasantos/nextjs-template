/**
 * Correlation ID tracking for distributed tracing
 *
 * Extracts, generates, and applies correlation headers for
 * request tracing across service boundaries
 *
 * Usage:
 * ```typescript
 * // In proxy.ts
 * const correlation = extractCorrelationFromHeaders(request.headers)
 * applyCorrelationHeaders(response.headers, correlation)
 * ```
 *
 * @module @workspace/logging/correlation
 */
import type { CorrelationProvenance } from "./contracts"

// Header names for correlation tracking
const LOG_TRACE_ID_HEADER = "x-trace-id"
const LOG_CORRELATION_ID_HEADER = "x-correlation-id"
const LOG_CORRELATION_PROVENANCE_HEADER = "x-correlation-provenance"
const LOG_REQUEST_URL_HEADER = "x-app-request-url"

type CorrelationContext = {
  correlationId: string
  correlationProvenance: CorrelationProvenance
  traceId: string
}

/**
 * Normalize identifier (trim, limit length)
 */
function normalizeIdentifier(value: string | null | undefined): string | null {
  const trimmed = value?.trim()
  if (!trimmed) {
    return null
  }
  return trimmed.slice(0, 128)
}

/**
 * Generate new correlation ID
 */
function generateCorrelationId(): string {
  return crypto.randomUUID()
}

/**
 * Extract trace ID from W3C traceparent header
 */
function extractTraceIdFromTraceparent(value: string | null): string | null {
  const normalized = normalizeIdentifier(value)
  if (!normalized) {
    return null
  }

  // Format: 00-<32-char-trace-id>-<16-char-span-id>-<2-char-flags>
  const match = normalized.match(/^[\da-f]{2}-([\da-f]{32})-[\da-f]{16}-[\da-f]{2}$/i)
  return match?.[1] ?? null
}

/**
 * Extract correlation context from request headers
 */
function extractCorrelationFromHeaders(headers: Headers): CorrelationContext {
  const inheritedTraceId =
    normalizeIdentifier(headers.get(LOG_TRACE_ID_HEADER)) ??
    extractTraceIdFromTraceparent(headers.get("traceparent"))
  const inheritedCorrelationId = normalizeIdentifier(headers.get(LOG_CORRELATION_ID_HEADER))

  if (inheritedTraceId && inheritedCorrelationId) {
    return {
      correlationId: inheritedCorrelationId,
      correlationProvenance: "inherited",
      traceId: inheritedTraceId,
    }
  }

  // Generate new correlation context
  const newCorrelationId = generateCorrelationId()
  const newTraceId = generateCorrelationId()

  return {
    correlationId: newCorrelationId,
    correlationProvenance: "generated",
    traceId: newTraceId,
  }
}

/**
 * Apply correlation headers to response
 */
function applyCorrelationHeaders(headers: Headers, correlation: CorrelationContext): Headers {
  headers.set(LOG_TRACE_ID_HEADER, correlation.traceId)
  headers.set(LOG_CORRELATION_ID_HEADER, correlation.correlationId)
  headers.set(LOG_CORRELATION_PROVENANCE_HEADER, correlation.correlationProvenance)
  return headers
}

/**
 * Create headers with correlation context
 */
function createCorrelationHeaders(
  correlation: CorrelationContext,
  initialHeaders?: Headers
): Headers {
  const headers = initialHeaders ? new Headers(initialHeaders) : new Headers()
  return applyCorrelationHeaders(headers, correlation)
}

/**
 * Get correlation context from headers helper
 */
function getCorrelationContext(headers: Headers): CorrelationContext {
  return extractCorrelationFromHeaders(headers)
}

/**
 * Execute function with correlation context
 */
function withCorrelationContext<T>(headers: Headers, fn: (context: CorrelationContext) => T): T {
  const context = extractCorrelationFromHeaders(headers)
  return fn(context)
}

export {
  LOG_CORRELATION_ID_HEADER,
  LOG_CORRELATION_PROVENANCE_HEADER,
  LOG_REQUEST_URL_HEADER,
  LOG_TRACE_ID_HEADER,
  applyCorrelationHeaders,
  createCorrelationHeaders,
  extractCorrelationFromHeaders,
  generateCorrelationId,
  getCorrelationContext,
  withCorrelationContext,
}
export type { CorrelationContext }
