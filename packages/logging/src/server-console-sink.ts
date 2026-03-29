import type { ObservabilityEvent } from "@workspace/logging/contracts"

type ServerConsoleMode = "full" | "minimal" | "off"

function resolveServerConsoleMode(
  env: NodeJS.ProcessEnv,
  environmentName: string
): ServerConsoleMode {
  const raw = env.OBSERVABILITY_SERVER_CONSOLE?.trim().toLowerCase()
  if (raw === "full" || raw === "minimal" || raw === "off") {
    return raw
  }
  return environmentName === "production" ? "minimal" : "full"
}

function formatServerConsolePayload(
  event: ObservabilityEvent,
  mode: ServerConsoleMode,
  isProductionLike: boolean
): string | null {
  if (mode === "off") {
    return null
  }
  if (mode === "minimal") {
    const parts = [
      "[observability]",
      event.severity,
      `${event.event_family}.${event.event_name}`,
      `outcome=${event.outcome}`,
      `correlation_id=${event.correlation_id}`,
      `trace_id=${event.trace_id}`,
      `service=${event.service}`,
      `component=${event.component}`,
    ]
    if (event.error_code) {
      parts.push(`error_code=${event.error_code}`)
    }
    return parts.join(" ")
  }
  return isProductionLike
    ? JSON.stringify(event)
    : JSON.stringify(event, null, 2)
}

export {
  type ServerConsoleMode,
  formatServerConsolePayload,
  resolveServerConsoleMode,
}
