import "server-only"

import { logServerEvent } from "@workspace/logging/server"

/**
 * @deprecated Use `@workspace/logging/server` directly.
 */
function logServerError(scope: string, message: string, cause?: unknown): void {
  void logServerEvent({
    component: scope,
    error: cause,
    eventFamily: "http.request",
    eventName: "deprecated_server_error_sink",
    metadata: { legacy_message: message },
    operation: message,
    operationType: "render",
    outcome: "failure",
    persist: true,
    service: "example",
  })
}

export { logServerError }
