import { describe, expect, it } from "vitest"

import { ObservabilityEventSchema } from "@workspace/logging/contracts"
import {
  formatServerConsolePayload,
  resolveServerConsoleMode,
} from "@workspace/logging/server-console-sink"

function baseEvent() {
  return ObservabilityEventSchema.parse({
    actor_id_hash: null,
    actor_type: "user",
    component: "test",
    correlation_id: "corr-1",
    correlation_provenance: "generated",
    duration_ms: null,
    environment: "development",
    error_category: null,
    error_code: null,
    error_message: null,
    event_family: "action.lifecycle",
    event_name: "test_action",
    http_status: null,
    ip_hash: null,
    metadata: {},
    operation: "noop",
    operation_type: "action",
    outcome: "success",
    persisted: false,
    request_path: null,
    role: null,
    runtime: "node",
    service: "test-service",
    severity: "info",
    timestamp: "2026-03-28T12:00:00.000Z",
    trace_id: "trace-1",
    user_agent: null,
  })
}

describe("resolveServerConsoleMode", () => {
  it("defaults to full when not production", () => {
    expect(resolveServerConsoleMode({}, "development")).toBe("full")
  })

  it("defaults to minimal in production when unset", () => {
    expect(resolveServerConsoleMode({}, "production")).toBe("minimal")
  })

  it("respects OBSERVABILITY_SERVER_CONSOLE", () => {
    expect(resolveServerConsoleMode({ OBSERVABILITY_SERVER_CONSOLE: "off" }, "production")).toBe(
      "off"
    )
    expect(resolveServerConsoleMode({ OBSERVABILITY_SERVER_CONSOLE: "full" }, "production")).toBe(
      "full"
    )
  })
})

describe("formatServerConsolePayload", () => {
  it("returns null for off", () => {
    expect(formatServerConsolePayload(baseEvent(), "off", false)).toBeNull()
  })

  it("minimal mode is a single line without full JSON", () => {
    const line = formatServerConsolePayload(baseEvent(), "minimal", true)
    expect(line).toContain("[observability]")
    expect(line).toContain("action.lifecycle.test_action")
    expect(line).toContain("correlation_id=corr-1")
    expect(line).not.toContain("{")
  })

  it("full mode pretty-prints when not production-like", () => {
    const json = formatServerConsolePayload(baseEvent(), "full", false)
    expect(json).toContain("\n")
    expect(json).toContain('"event_name"')
  })

  it("full mode compacts JSON in production-like formatting flag", () => {
    const json = formatServerConsolePayload(baseEvent(), "full", true)
    expect(json).not.toContain("\n")
    expect(json).toContain('"event_name":"test_action"')
  })
})
