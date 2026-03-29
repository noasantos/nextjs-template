# @workspace/logging

Shared observability package for structured logging, correlation, redaction, and runtime-safe event emission.

## Purpose

This package is the only shared observability contract for the monorepo.

Use it for:

- canonical event types
- request correlation
- safe metadata handling
- safe error serialization
- server event emission
- browser error-boundary reporting
- future Edge Function observability

Do not create local logger wrappers in apps or packages.

## Exports

| Export                           | Purpose                                                           |
| -------------------------------- | ----------------------------------------------------------------- |
| `@workspace/logging/contracts`   | Canonical event schema and enums                                  |
| `@workspace/logging/correlation` | Correlation header extraction and propagation                     |
| `@workspace/logging/redaction`   | Metadata sanitization, request-path safety, deterministic hashing |
| `@workspace/logging/errors`      | Error categorization and serialization                            |
| `@workspace/logging/server`      | Node and Next.js observability helpers                            |
| `@workspace/logging/client`      | Browser-side error-boundary reporting                             |
| `@workspace/logging/edge`        | Future Edge Function helper surface                               |
| `@workspace/logging/testing`     | Event fixtures for tests                                          |

## Rules

- log one rich boundary event instead of multiple thin checkpoint logs
- keep user-facing errors generic and internal events specific
- never log raw secrets, tokens, cookies, emails, phone numbers, or full request bodies
- hash identifiers when correlation is needed
- seed correlation at ingress, not deep in business logic

## Examples

Server route or page boundary:

```ts
const context = await createServerObservabilityContext({
  headers: request.headers,
  requestPath: request.url,
})

return withServerObservabilityContext(context, async () => {
  await logServerEvent({
    component: "auth.callback",
    eventFamily: "auth.flow",
    eventName: "callback_exchange_succeeded",
    operation: "exchange_code_for_session",
    operationType: "auth",
    outcome: "success",
    persist: true,
    service: "auth",
  })
})
```

Browser error boundary:

```ts
reportBrowserUiError({
  component: "adm.utilizadores.error_boundary",
  error,
  service: "example",
})
```

Future Edge Function:

```ts
logEdgeEvent({
  component: "edge.webhook",
  eventName: "edge_request_failed",
  operation: "processWebhook",
  outcome: "failure",
  request,
  service: "edge-runtime",
})
```

## Never log

- `Authorization`
- cookies
- JWTs
- service role secrets
- OTPs or token hashes
- email addresses
- phone numbers
- full names
- full provider payloads
