/**
 * Logging contracts and type definitions
 *
 * Defines the canonical observability event schema used throughout
 * the application for structured logging
 *
 * @module @workspace/logging/contracts
 */
import { z } from "zod"

// Event families for categorizing logs
const eventFamilies = [
  "http.request",
  "auth.flow",
  "action.lifecycle",
  "privileged.operation",
  "supabase.integration",
  "ui.error",
  "ui.event",
  "ui.performance",
  "edge.request",
  "webhook.lifecycle",
  "security.audit",
  "realtime.lifecycle",
  "realtime.message",
] as const

// Outcomes for operations
const outcomes = ["success", "failure", "unknown"] as const

// Actor types
const actorTypes = ["anonymous", "user", "service", "system", "admin", "unknown"] as const

// Operation types
const operationTypes = [
  "http",
  "auth",
  "action",
  "query",
  "mutation",
  "rpc",
  "admin",
  "render",
  "webhook",
  "edge",
  "subscription",
  "event",
  "cleanup",
] as const

// Error categories
const errorCategories = [
  "validation",
  "authentication",
  "authorization",
  "business",
  "not_found",
  "conflict",
  "database",
  "supabase_auth",
  "supabase_rls",
  "integration",
  "network",
  "unknown",
] as const

// Correlation provenance
const correlationProvenances = ["generated", "inherited"] as const

// Runtime environments
const runtimes = ["node", "edge", "browser"] as const

// Severity levels
const severities = ["debug", "info", "warn", "error"] as const

// JSON value schema for metadata
const JsonValueSchema: z.ZodType<unknown> = z.lazy(
  (): z.ZodType<unknown> =>
    z.union([
      z.string(),
      z.number(),
      z.boolean(),
      z.null(),
      z.array(JsonValueSchema),
      z.record(z.string(), JsonValueSchema),
    ])
)

// Main observability event schema
const ObservabilityEventSchema = z.object({
  actor_id_hash: z.string().nullable(),
  actor_type: z.enum(actorTypes),
  component: z.string().min(1),
  correlation_id: z.string().min(1),
  correlation_provenance: z.enum(correlationProvenances),
  duration_ms: z.number().int().nonnegative().nullable(),
  environment: z.string().min(1),
  error_category: z.enum(errorCategories).nullable(),
  error_code: z.string().nullable(),
  error_message: z.string().nullable(),
  event_family: z.enum(eventFamilies),
  event_name: z.string().min(1),
  http_status: z.number().int().nullable(),
  ip_hash: z.string().nullable(),
  metadata: z.record(z.string(), JsonValueSchema),
  operation: z.string().min(1),
  operation_type: z.enum(operationTypes),
  outcome: z.enum(outcomes),
  persisted: z.boolean(),
  request_path: z.string().nullable(),
  role: z.string().nullable(),
  runtime: z.enum(runtimes),
  service: z.string().min(1),
  severity: z.enum(severities),
  timestamp: z.string().datetime(),
  trace_id: z.string().min(1),
  user_agent: z.string().nullable(),
})

// Type exports
type EventFamily = (typeof eventFamilies)[number]
type Outcome = (typeof outcomes)[number]
type ActorType = (typeof actorTypes)[number]
type OperationType = (typeof operationTypes)[number]
type ErrorCategory = (typeof errorCategories)[number]
type CorrelationProvenance = (typeof correlationProvenances)[number]
type Runtime = (typeof runtimes)[number]
type Severity = (typeof severities)[number]
type ObservabilityEvent = z.infer<typeof ObservabilityEventSchema>

export {
  ObservabilityEventSchema,
  JsonValueSchema,
  actorTypes,
  correlationProvenances,
  errorCategories,
  eventFamilies,
  operationTypes,
  outcomes,
  runtimes,
  severities,
}
export type {
  ActorType,
  CorrelationProvenance,
  ErrorCategory,
  EventFamily,
  ObservabilityEvent,
  OperationType,
  Outcome,
  Runtime,
  Severity,
}
export type JsonValue = z.infer<typeof JsonValueSchema>
