import "server-only"

import { AsyncLocalStorage } from "node:async_hooks"

import { createClient } from "@supabase/supabase-js"

import { getSupabaseServerEnv } from "@workspace/supabase-infra/env/server"
import type { Database } from "@workspace/supabase-infra/types/database"
import type {
  ActorType,
  EventFamily,
  ObservabilityEvent,
  OperationType,
  Outcome,
  Severity,
} from "@workspace/logging/contracts"
import { ObservabilityEventSchema } from "@workspace/logging/contracts"
import {
  type CorrelationContext,
  extractCorrelationFromHeaders,
  generateCorrelationId,
} from "@workspace/logging/correlation"
import { serializeUnknownError } from "@workspace/logging/errors"
import {
  getIpAddressFromHeaders,
  hashDeterministic,
  sanitizeMetadata,
  sanitizeRequestPath,
} from "@workspace/logging/redaction"
import {
  formatServerConsolePayload,
  resolveServerConsoleMode,
} from "@workspace/logging/server-console-sink"

type ServerObservabilityContext = {
  correlation: CorrelationContext
  ipAddress: string | null
  requestPath: string | null
  userAgent: string | null
}

type ServerEventInput = {
  actorId?: string | null
  actorType?: ActorType
  component: string
  durationMs?: number | null
  error?: unknown
  eventFamily: EventFamily
  eventName: string
  httpStatus?: number | null
  metadata?: Record<string, unknown>
  operation: string
  operationType: OperationType
  outcome: Outcome
  persist?: boolean
  requestPath?: string | null
  role?: string | null
  service: string
  severity?: Severity
}

const contextStore = new AsyncLocalStorage<ServerObservabilityContext>()
let cachedAdminClient: ReturnType<typeof createClient<Database>> | null = null

async function createServerObservabilityContext({
  headers,
  requestPath,
}: {
  headers: Headers
  requestPath?: string | null
}): Promise<ServerObservabilityContext> {
  return {
    correlation: extractCorrelationFromHeaders(headers),
    ipAddress: getIpAddressFromHeaders(headers),
    requestPath:
      sanitizeRequestPath(requestPath) ??
      sanitizeRequestPath(headers.get("x-app-request-url")),
    userAgent: headers.get("user-agent"),
  }
}

function withServerObservabilityContext<T>(
  context: ServerObservabilityContext,
  callback: () => Promise<T> | T
): Promise<T> | T {
  return contextStore.run(context, callback)
}

function getServerObservabilityContext(): ServerObservabilityContext | null {
  return contextStore.getStore() ?? null
}

async function logServerEvent(
  input: ServerEventInput
): Promise<ObservabilityEvent> {
  const context = getServerObservabilityContext()
  const error = input.error ? serializeUnknownError(input.error) : null

  const event = ObservabilityEventSchema.parse({
    actor_id_hash: await hashDeterministic(input.actorId),
    actor_type: input.actorType ?? "unknown",
    component: input.component,
    correlation_id:
      context?.correlation.correlationId ?? generateCorrelationId(),
    correlation_provenance:
      context?.correlation.correlationProvenance ?? "generated",
    duration_ms: input.durationMs ?? null,
    environment: getEnvironmentName(),
    error_category: error?.category ?? null,
    error_code: error?.code ?? null,
    error_message: error?.message ?? null,
    event_family: input.eventFamily,
    event_name: input.eventName,
    http_status: input.httpStatus ?? null,
    ip_hash: await hashDeterministic(context?.ipAddress),
    metadata: sanitizeMetadata(input.metadata ?? {}) as Record<string, unknown>,
    operation: input.operation,
    operation_type: input.operationType,
    outcome: input.outcome,
    persisted: false,
    request_path:
      sanitizeRequestPath(input.requestPath) ?? context?.requestPath ?? null,
    role: input.role ?? null,
    runtime: "node",
    service: input.service,
    severity: input.severity ?? defaultSeverityForOutcome(input.outcome),
    timestamp: new Date().toISOString(),
    trace_id: context?.correlation.traceId ?? generateCorrelationId(),
    user_agent: context?.userAgent ?? null,
  })

  writeConsoleEvent(event)

  const persisted = await persistServerEvent(event, input.persist ?? false)
  return {
    ...event,
    persisted,
  }
}

function getEnvironmentName(): string {
  return (
    process.env.VERCEL_ENV?.trim() ||
    process.env.NODE_ENV?.trim() ||
    "development"
  )
}

function defaultSeverityForOutcome(outcome: Outcome): Severity {
  return outcome === "failure" ? "error" : "info"
}

function writeConsoleEvent(event: ObservabilityEvent): void {
  const environmentName = getEnvironmentName()
  const isProductionLike = environmentName === "production"
  const mode = resolveServerConsoleMode(process.env, environmentName)
  const payload = formatServerConsolePayload(event, mode, isProductionLike)
  if (payload === null) {
    return
  }

  if (event.severity === "error") {
    console.error(payload)
    return
  }

  if (event.severity === "warn") {
    console.warn(payload)
    return
  }

  console.info(payload)
}

async function persistServerEvent(
  event: ObservabilityEvent,
  forced: boolean
): Promise<boolean> {
  if (!shouldPersistEvent(event, forced)) {
    return false
  }

  try {
    const client = getObservabilityAdminClient()
    const row: Database["public"]["Tables"]["observability_events"]["Insert"] =
      {
        actor_id_hash: event.actor_id_hash,
        actor_type: event.actor_type,
        component: event.component,
        correlation_id: event.correlation_id,
        correlation_provenance: event.correlation_provenance,
        duration_ms: event.duration_ms,
        environment: event.environment,
        error_category: event.error_category,
        error_code: event.error_code,
        error_message: event.error_message,
        event_family: event.event_family,
        event_name: event.event_name,
        http_status: event.http_status,
        ip_hash: event.ip_hash,
        metadata:
          event.metadata as Database["public"]["Tables"]["observability_events"]["Insert"]["metadata"],
        operation: event.operation,
        operation_type: event.operation_type,
        outcome: event.outcome,
        request_path: event.request_path,
        role: event.role,
        runtime: event.runtime,
        service: event.service,
        severity: event.severity,
        timestamp: event.timestamp,
        trace_id: event.trace_id,
        user_agent: event.user_agent,
      }
    const { error } = await client.from("observability_events").insert(row)

    return !error
  } catch {
    return false
  }
}

function shouldPersistEvent(
  event: ObservabilityEvent,
  forced: boolean
): boolean {
  if (forced) {
    return true
  }

  const envFlag = process.env.OBSERVABILITY_PERSIST_EVENTS?.trim()
  if (envFlag === "true") {
    return true
  }

  if (getEnvironmentName() === "production") {
    return true
  }

  return (
    event.outcome === "failure" ||
    event.event_family === "privileged.operation" ||
    event.event_family === "security.audit"
  )
}

function getObservabilityAdminClient() {
  if (cachedAdminClient) {
    return cachedAdminClient
  }

  const { serviceRoleKey, supabaseUrl } = getSupabaseServerEnv()
  cachedAdminClient = createClient<Database>(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  })

  return cachedAdminClient
}

export {
  createServerObservabilityContext,
  getServerObservabilityContext,
  logServerEvent,
  withServerObservabilityContext,
}
export type { ServerEventInput, ServerObservabilityContext }
