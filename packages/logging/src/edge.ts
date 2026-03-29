import type { ObservabilityEvent } from "@workspace/logging/contracts"
import { ObservabilityEventSchema } from "@workspace/logging/contracts"
import type { CorrelationContext } from "@workspace/logging/correlation"
import {
  extractCorrelationFromHeaders,
  generateCorrelationId,
} from "@workspace/logging/correlation"
import { serializeUnknownError } from "@workspace/logging/errors"
import {
  sanitizeMetadata,
  sanitizeRequestPath,
} from "@workspace/logging/redaction"

type EdgeEventInput = {
  component: string
  correlation?: CorrelationContext
  error?: unknown
  eventName: string
  metadata?: Record<string, unknown>
  operation: string
  outcome: "success" | "failure" | "unknown"
  request: Request
  service: string
}

function createEdgeCorrelation(request: Request): CorrelationContext {
  return extractCorrelationFromHeaders(request.headers)
}

function logEdgeEvent(input: EdgeEventInput): ObservabilityEvent {
  const correlation = input.correlation ?? createEdgeCorrelation(input.request)
  const error = input.error ? serializeUnknownError(input.error) : null
  const event = ObservabilityEventSchema.parse({
    actor_id_hash: null,
    actor_type: "unknown",
    component: input.component,
    correlation_id: correlation.correlationId,
    correlation_provenance: correlation.correlationProvenance,
    duration_ms: null,
    environment:
      process.env.DENO_DEPLOYMENT_ID?.trim() ||
      process.env.NODE_ENV?.trim() ||
      "development",
    error_category: error?.category ?? null,
    error_code: error?.code ?? null,
    error_message: error?.message ?? null,
    event_family: "edge.request",
    event_name: input.eventName,
    http_status: null,
    ip_hash: null,
    metadata: sanitizeMetadata(input.metadata ?? {}) as Record<string, unknown>,
    operation: input.operation,
    operation_type: "edge",
    outcome: input.outcome,
    persisted: false,
    request_path: sanitizeRequestPath(input.request.url),
    role: null,
    runtime: "edge",
    service: input.service,
    severity: input.outcome === "failure" ? "error" : "info",
    timestamp: new Date().toISOString(),
    trace_id: correlation.traceId ?? generateCorrelationId(),
    user_agent: input.request.headers.get("user-agent"),
  })

  console.info(JSON.stringify(event))
  return event
}

export { createEdgeCorrelation, logEdgeEvent }
