/**
 * Client-side logging for browser operations
 *
 * This is the **ONLY** approved way to log in client-side code.
 * It sends logs to the server for structured storage.
 *
 * ## Architecture
 *
 * Client logging sends events to server via HTTP POST:
 *
 * ```
 * Browser Component
 *      ↓
 * logClientEvent()
 *      ↓
 * POST /api/log
 *      ↓
 * Server receives and logs with logServerEvent()
 *      ↓
 * Stored in observability_events table
 * ```
 *
 * ## When to Use
 *
 * **Use client logging for:**
 * - ✅ User interactions (clicks, form submissions)
 * - ✅ Client-side errors (React errors, API failures)
 * - ✅ Performance metrics (page load, render time)
 * - ✅ Analytics events (page views, feature usage)
 *
 * **Do NOT use for:**
 * - ❌ Server-side operations (use logServerEvent)
 * - ❌ Sensitive data (passwords, tokens)
 * - ❌ High-frequency events (use sampling)
 *
 * ## Usage
 *
 * ```typescript
 * "use client"
 *
 * import { logClientEvent } from "@workspace/logging/client"
 *
 * export function MyComponent() {
 *   const handleClick = async () => {
 *     await logClientEvent({
 *       component: "my.component",
 *       eventFamily: "ui.event",
 *       eventName: "button_clicked",
 *       outcome: "success",
 *       metadata: {
 *         buttonType: "submit",
 *         formId: "contact-form",
 *       },
 *     })
 *   }
 *
 *   return <button onClick={handleClick}>Click me</button>
 * }
 * ```
 *
 * ## Error Logging
 *
 * ```typescript
 * "use client"
 *
 * import { logClientEvent } from "@workspace/logging/client"
 *
 * // Log React errors
 * try {
 *   riskyOperation()
 * } catch (error) {
 *   await logClientEvent({
 *     component: "my.component",
 *     eventFamily: "ui.error",
 *     eventName: "operation_failed",
 *     outcome: "failure",
 *     error,
 *     metadata: {
 *       operationName: "riskyOperation",
 *     },
 *   })
 * }
 * ```
 *
 * ## Performance Metrics
 *
 * ```typescript
 * "use client"
 *
 * import { logClientEvent } from "@workspace/logging/client"
 *
 * // Log page load time
 * useEffect(() => {
 *   const loadTime = performance.now()
 *
 *   logClientEvent({
 *     component: "page",
 *     eventFamily: "ui.performance",
 *     eventName: "page_loaded",
 *     outcome: "success",
 *     durationMs: loadTime,
 *     metadata: {
 *       pageName: "dashboard",
 *       url: window.location.href,
 *     },
 *   })
 * }, [])
 * ```
 *
 * @see {@link logServerEvent} - Server-side logging
 *
 * @module @workspace/logging/client
 */
"use client"

import type { EventFamily, Outcome, OperationType, Severity } from "./contracts"

/**
 * Client-side log event input
 */
export interface ClientEventInput {
  component: string
  eventFamily: EventFamily
  eventName: string
  outcome: Outcome
  operation?: string
  operationType?: OperationType
  severity?: Severity
  durationMs?: number | null
  error?: unknown
  metadata?: Record<string, unknown>
}

/**
 * Send log event to server
 *
 * Posts event to /api/log endpoint which processes
 * and stores it with server-side logging.
 *
 * @param input - Event details
 * @returns Promise that resolves when logged
 */
export async function logClientEvent(input: ClientEventInput): Promise<void> {
  try {
    // Send to server endpoint
    const response = await fetch("/api/log", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(input),
    })

    if (!response.ok) {
      // Log to console if server logging fails (fallback)
      console.error("[ClientLogger] Failed to send log to server", response.status)
    }
  } catch (error) {
    // Fallback to console if fetch fails
    console.error("[ClientLogger] Failed to send log", error)
  }
}

/**
 * Log client error helper
 *
 * Simplifies error logging with proper defaults.
 *
 * @param component - Component where error occurred
 * @param error - Error object
 * @param metadata - Additional context
 */
export async function logClientError(
  component: string,
  error: unknown,
  metadata?: Record<string, unknown> | undefined
): Promise<void> {
  await logClientEvent({
    component,
    eventFamily: "ui.error",
    eventName: "client_error",
    outcome: "failure",
    error,
    severity: "error",
    ...(metadata && { metadata }),
  })
}

/**
 * Log user interaction helper
 *
 * Simplifies logging user interactions.
 *
 * @param component - Component where interaction occurred
 * @param eventName - Name of interaction (e.g., "button_clicked")
 * @param metadata - Additional context
 */
export async function logUserInteraction(
  component: string,
  eventName: string,
  metadata?: Record<string, unknown> | undefined
): Promise<void> {
  await logClientEvent({
    component,
    eventFamily: "ui.event",
    eventName,
    outcome: "success",
    operation: eventName,
    operationType: "render",
    severity: "info",
    ...(metadata && { metadata }),
  })
}
