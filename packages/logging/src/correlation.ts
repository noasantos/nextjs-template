import type { CorrelationProvenance } from "@workspace/logging/contracts"

const LOG_TRACE_ID_HEADER = "x-trace-id"
const LOG_CORRELATION_ID_HEADER = "x-correlation-id"
const LOG_CORRELATION_PROVENANCE_HEADER = "x-correlation-provenance"
const LOG_REQUEST_URL_HEADER = "x-app-request-url"

type CorrelationContext = {
  correlationId: string
  correlationProvenance: CorrelationProvenance
  traceId: string
}

function normalizeIdentifier(value: string | null | undefined): string | null {
  const trimmed = value?.trim()
  if (!trimmed) {
    return null
  }

  return trimmed.slice(0, 128)
}

function generateCorrelationId(): string {
  return crypto.randomUUID()
}

function extractTraceIdFromTraceparent(value: string | null): string | null {
  const normalized = normalizeIdentifier(value)
  if (!normalized) {
    return null
  }

  const match = normalized.match(
    /^[\da-f]{2}-([\da-f]{32})-[\da-f]{16}-[\da-f]{2}$/i
  )
  return match?.[1] ?? null
}

function extractCorrelationFromHeaders(headers: Headers): CorrelationContext {
  const inheritedTraceId =
    normalizeIdentifier(headers.get(LOG_TRACE_ID_HEADER)) ??
    extractTraceIdFromTraceparent(headers.get("traceparent"))
  const inheritedCorrelationId = normalizeIdentifier(
    headers.get(LOG_CORRELATION_ID_HEADER)
  )

  if (inheritedTraceId && inheritedCorrelationId) {
    return {
      correlationId: inheritedCorrelationId,
      correlationProvenance: "inherited",
      traceId: inheritedTraceId,
    }
  }

  return {
    correlationId: inheritedCorrelationId ?? generateCorrelationId(),
    correlationProvenance: "generated",
    traceId: inheritedTraceId ?? generateCorrelationId(),
  }
}

function applyCorrelationHeaders(
  headers: Headers,
  correlation: CorrelationContext
): Headers {
  headers.set(LOG_TRACE_ID_HEADER, correlation.traceId)
  headers.set(LOG_CORRELATION_ID_HEADER, correlation.correlationId)
  headers.set(
    LOG_CORRELATION_PROVENANCE_HEADER,
    correlation.correlationProvenance
  )

  return headers
}

function getCorrelationFromHeaderMap(
  headersInit: Headers | Record<string, string | null | undefined>
): CorrelationContext {
  if (headersInit instanceof Headers) {
    return extractCorrelationFromHeaders(headersInit)
  }

  const headers = new Headers()
  for (const [key, value] of Object.entries(headersInit)) {
    if (typeof value === "string") {
      headers.set(key, value)
    }
  }

  return extractCorrelationFromHeaders(headers)
}

function createCorrelationHeaders(
  correlation: CorrelationContext,
  initialHeaders?: Headers
): Headers {
  const headers = initialHeaders ? new Headers(initialHeaders) : new Headers()
  return applyCorrelationHeaders(headers, correlation)
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
  getCorrelationFromHeaderMap,
}
export type { CorrelationContext }
