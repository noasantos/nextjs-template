import { sanitizeMetadata } from "@workspace/logging/redaction"

type BrowserUiErrorInput = {
  component: string
  error: Error & { digest?: string }
  metadata?: Record<string, unknown>
  service: string
}

function reportBrowserUiError({
  component,
  error,
  metadata,
  service,
}: BrowserUiErrorInput): void {
  const payload = {
    component,
    error_category: "unknown",
    error_code: error.name,
    error_message: error.message,
    event_family: "ui.error",
    event_name: "ui_error_boundary",
    metadata: sanitizeMetadata({
      ...metadata,
      digest: error.digest ?? null,
    }),
    outcome: "failure",
    runtime: "browser",
    service,
    timestamp: new Date().toISOString(),
  }

  console.error(JSON.stringify(payload))
}

export { reportBrowserUiError }
