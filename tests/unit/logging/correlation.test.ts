import { describe, expect, it } from "vitest"

import {
  LOG_CORRELATION_ID_HEADER,
  LOG_TRACE_ID_HEADER,
  applyCorrelationHeaders,
  extractCorrelationFromHeaders,
} from "@workspace/logging/correlation"

describe("correlation helpers", () => {
  it("inherits explicit trace and correlation identifiers from headers", () => {
    const headers = new Headers({
      [LOG_CORRELATION_ID_HEADER]: "corr-123",
      [LOG_TRACE_ID_HEADER]: "trace-456",
    })

    expect(extractCorrelationFromHeaders(headers)).toEqual({
      correlationId: "corr-123",
      correlationProvenance: "inherited",
      traceId: "trace-456",
    })
  })

  it("generates identifiers when headers are missing", () => {
    const result = extractCorrelationFromHeaders(new Headers())

    expect(result.correlationId).toBeTruthy()
    expect(result.traceId).toBeTruthy()
    expect(result.correlationProvenance).toBe("generated")
  })

  it("writes correlation fields back into request headers", () => {
    const headers = applyCorrelationHeaders(new Headers(), {
      correlationId: "corr-1",
      correlationProvenance: "generated",
      traceId: "trace-1",
    })

    expect(headers.get(LOG_CORRELATION_ID_HEADER)).toBe("corr-1")
    expect(headers.get(LOG_TRACE_ID_HEADER)).toBe("trace-1")
  })
})
