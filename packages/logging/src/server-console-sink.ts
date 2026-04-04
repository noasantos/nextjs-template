/**
 * Server console output formatting
 *
 * Formats observability events for console output in development.
 * In production, logs are minimal to reduce noise.
 *
 * @module @workspace/logging/server-console-sink
 */
import type { ObservabilityEvent } from "./contracts"

/**
 * Console output mode
 */
export type ConsoleMode = "pretty" | "json" | "minimal"

/**
 * Resolve console mode based on environment
 *
 * @param env - Process environment
 * @param environmentName - Environment name
 * @returns Console mode
 */
export function resolveServerConsoleMode(
  env: NodeJS.ProcessEnv,
  environmentName: string
): ConsoleMode {
  // Production: minimal output
  if (environmentName === "production") {
    return "minimal"
  }

  // CI: JSON for parsing
  if (env.CI === "true") {
    return "json"
  }

  // Development: pretty output
  return "pretty"
}

/**
 * Format event for console output
 *
 * @param event - Observability event
 * @param mode - Console mode
 * @param isProductionLike - Whether running in production-like environment
 * @returns Formatted payload or null to skip logging
 */
export function formatServerConsolePayload(
  event: ObservabilityEvent,
  mode: ConsoleMode,
  _isProductionLike: boolean
): string | null {
  // Minimal mode: only errors
  if (mode === "minimal" && event.severity !== "error") {
    return null
  }

  // JSON mode: full event
  if (mode === "json") {
    return JSON.stringify(event)
  }

  // Pretty mode: formatted output
  if (mode === "pretty") {
    return formatPrettyConsole(event)
  }

  return null
}

/**
 * Format event as pretty console output
 */
function formatPrettyConsole(event: ObservabilityEvent): string {
  const timestamp = new Date(event.timestamp).toLocaleTimeString()
  const severity = getSeverityEmoji(event.severity)
  const family = event.event_family
  const name = event.event_name

  let output = `${timestamp} ${severity} [${family}] ${name}`

  // Add duration if available
  if (event.duration_ms !== null) {
    output += ` (${event.duration_ms}ms)`
  }

  // Add error details if failure
  if (event.outcome === "failure" && event.error_message) {
    output += `\n  Error: ${event.error_message}`
  }

  // Add metadata preview (first 3 keys)
  const metadataKeys = Object.keys(event.metadata)
  if (metadataKeys.length > 0) {
    const preview = metadataKeys.slice(0, 3).join(", ")
    output += `\n  Metadata: { ${preview}${metadataKeys.length > 3 ? "..." : ""} }`
  }

  return output
}

/**
 * Get emoji for severity level
 */
function getSeverityEmoji(severity: string): string {
  switch (severity) {
    case "error":
      return "❌"
    case "warn":
      return "⚠️"
    case "info":
      return "ℹ️"
    case "debug":
      return "🔍"
    default:
      return "•"
  }
}
