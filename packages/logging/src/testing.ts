import type { ObservabilityEvent } from "@workspace/logging/contracts"

function createObservabilityEventFixture(
  overrides: Partial<ObservabilityEvent> = {}
): ObservabilityEvent {
  return {
    actor_id_hash: null,
    actor_type: "unknown",
    component: "test.component",
    correlation_id: "correlation-1",
    correlation_provenance: "generated",
    duration_ms: 1,
    environment: "test",
    error_category: null,
    error_code: null,
    error_message: null,
    event_family: "action.lifecycle",
    event_name: "test_event",
    http_status: null,
    ip_hash: null,
    metadata: {},
    operation: "test.operation",
    operation_type: "action",
    outcome: "success",
    persisted: false,
    request_path: "/test",
    role: null,
    runtime: "node",
    service: "test",
    severity: "info",
    timestamp: new Date("2026-03-25T00:00:00.000Z").toISOString(),
    trace_id: "trace-1",
    user_agent: null,
    ...overrides,
  }
}

export { createObservabilityEventFixture }
