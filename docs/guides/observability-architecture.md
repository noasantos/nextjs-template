# Observability Architecture

Observability standard for this repository (structured logging, correlation, redaction).

## Why this exists

This repo does not want more logs. It wants fewer, richer, correlateable events that explain what happened without leaking sensitive data. The goal is boundary-first observability:

- correlation begins at ingress
- important boundaries emit structured lifecycle events
- failures remain diagnosable after user-facing errors are simplified
- privileged operations leave an auditable trail
- sensitive data never becomes a debugging shortcut

## One source of truth

Use `@workspace/logging` everywhere for observability concerns.

- Use `@workspace/logging/contracts` — source: [`packages/logging/src/contracts.ts`](../packages/logging/src/contracts.ts).
- Use `@workspace/logging/correlation` — [`packages/logging/src/correlation.ts`](../packages/logging/src/correlation.ts).
- Use `@workspace/logging/redaction` — [`packages/logging/src/redaction.ts`](../packages/logging/src/redaction.ts).
- Use `@workspace/logging/errors` — [`packages/logging/src/errors.ts`](../packages/logging/src/errors.ts).
- Use `@workspace/logging/server` — [`packages/logging/src/server.ts`](../packages/logging/src/server.ts).
- Use `@workspace/logging/client` — [`packages/logging/src/client.ts`](../packages/logging/src/client.ts).
- Use `@workspace/logging/edge` — [`packages/logging/src/edge.ts`](../packages/logging/src/edge.ts).

Do not create:

- app-local logger wrappers
- copied redaction helpers
- copied correlation parsers
- direct `console.*` in product code

Exception: `@workspace/logging/client` `reportBrowserUiError` intentionally writes a single JSON line to the browser `console.error` for local debugging. That is **not** persisted to Postgres and **not** the same as the server dual sink below.

## What counts as a “meaningful” action (scope)

The standard is **boundary-first**, not “every line of code”:

- **In scope for structured events:** HTTP/app ingress, auth lifecycle (sign-in/out/callback), server actions and mutations, privileged or service-role work, security-relevant changes, integration failures, and UI error boundaries.
- **Out of scope for success-path spam:** routine repository reads (including session/claims resolution like `getClaims`) unless the read is privileged, incident-driven, or you explicitly need an audit trail for that path. Those stay **failure-only by default**.

“Every meaningful user action” in product language means **user-visible or security-relevant boundaries**, aligned with the lists in [Success and failure guidance](#success-and-failure-guidance) — not a literal log line on every successful `select`.

Adoption of older code paths remains **incremental**; new work should implement this contract at touched boundaries.

## Canonical event contract

Every high-value event uses the same shape:

- `event_family`
- `event_name`
- `timestamp`
- `trace_id`
- `correlation_id`
- `correlation_provenance`
- `service`
- `component`
- `runtime`
- `environment`
- `actor_type`
- `actor_id_hash`
- `role`
- `operation`
- `operation_type`
- `outcome`
- `error_category`
- `error_code`
- `error_message`
- `duration_ms`
- `request_path`
- `http_status`
- `user_agent`
- `ip_hash`
- `metadata`
- `severity`
- `persisted`

Rules:

- `request_path` must be normalized path only. Never log full URLs with secrets or query strings.
- `metadata` must be shaped and bounded. Do not dump arbitrary request or response objects.
- `actor_id_hash` and `ip_hash` are hashed, not raw.
- `persisted` means the event was successfully inserted into `observability_events`.

## Server sinks: console and database

`logServerEvent` uses **two independent sinks**:

1. **Process console** (`console.info` / `warn` / `error`) — always evaluated; formatting is controlled by `OBSERVABILITY_SERVER_CONSOLE` (see [Environment variables for observability](#environment-variables-for-observability)).
2. **Postgres** (`public.observability_events`) — gated by `shouldPersistEvent` / `persist:`; failures to insert must not break the request.

Persistence is **additional** evidence, not a replacement for console. In **production**, the default console mode is **`minimal`** (one line with correlation/trace/family/name/outcome) so hosted logs stay grep-friendly. Set `OBSERVABILITY_SERVER_CONSOLE=full` when you need full JSON in stdout (for example log drains that parse the full event). Set `OBSERVABILITY_SERVER_CONSOLE=off` to suppress server console emission while still persisting when rules match (use sparingly; you lose live tail visibility).

## Event families

Mandatory families:

- `http.request`
- `auth.flow`
- `action.lifecycle`
- `privileged.operation`
- `supabase.integration`
- `ui.error`
- `edge.request`
- `webhook.lifecycle`
- `security.audit`

Use one rich event per important boundary, not thin checkpoint spam.

Good event:

- one `action.lifecycle` failure with `failure_phase`, `error_code`, `duration_ms`, `actor_id_hash`, and domain metadata

Bad event:

- `starting`
- `got here`
- `step 2`
- `done`

## Boundary and correlation rules

### Ingress

Seed correlation in:

- [`apps/example/proxy.ts`](../apps/example/proxy.ts)

Apps that do not use the session `proxy` must document their own ingress/correlation story.

Ingress behavior:

- accept trusted incoming `traceparent`, `x-trace-id`, and `x-correlation-id`
- generate missing IDs
- set `x-correlation-provenance` to `generated` or `inherited`
- forward those headers to the downstream request

### Server runtime propagation

Use `createServerObservabilityContext` plus `withServerObservabilityContext` at major boundaries:

- route handlers
- app-layer server actions
- page/server-component boundaries where failures are meaningful

Inner action and service code should read correlation from the shared server logger rather than threading IDs through business DTOs.

### Outbound propagation

When introducing outbound HTTP, webhook delivery, or jobs later:

- copy trace and correlation IDs into outbound headers
- keep business logic unaware of header details by using the correlation helper

## Success and failure guidance

Success events are required for:

- auth callback completion
- logout
- privileged writes
- security-sensitive access changes
- future webhook and edge completions

Failure events are required for:

- any public route boundary
- action authorization denials
- repository failures that affect control flow
- session refresh failures
- service-role failures
- browser error boundaries

Repository read successes are failure-only by default unless the read is itself privileged or incident-relevant.

## Error semantics

Use these categories:

- `validation`
- `authentication`
- `authorization`
- `business`
- `not_found`
- `conflict`
- `database`
- `supabase_auth`
- `supabase_rls`
- `integration`
- `network`
- `unknown`

Required failure metadata:

- `failure_phase`

Allowed `failure_phase` values today:

- `parse`
- `authorize`
- `repository`
- `rpc`
- `gotrue`
- `render`
- `session_refresh`
- `webhook_verify`
- `edge_handler`

Keep `error_message` short and sanitized. Preserve upstream machine codes in `error_code` where available.

## Metadata guidance

Meaningful metadata answers “what changed or was attempted?” without replaying the full payload.

Good metadata examples:

- `role_count`
- `override_count`
- `effective_permissions`
- `limit`
- `row_count`
- `failure_phase`
- `reason`
- `status`

Bad metadata examples:

- full form payload
- raw cookies or JWTs
- raw auth provider responses
- entire Supabase row dumps
- stack traces

## Security and redaction

Never log raw:

- `Authorization`
- cookies
- JWTs
- service role keys
- OTPs
- token hashes
- webhook signatures
- emails
- phone numbers
- full names
- free-form request and response bodies

Use deterministic hashing for correlating identifiers. The hash key is `OBSERVABILITY_HASH_SECRET`.

Production rule:

- `OBSERVABILITY_HASH_SECRET` must be set in secure runtime configuration

Local development rule:

- a deterministic local fallback is acceptable for dev-only debugging

## Environment variables for observability

Document these in root [`.env.example`](../../.env.example) (this section summarizes behavior):

| Variable | Role |
|----------|------|
| `OBSERVABILITY_HASH_SECRET` | Server-only secret for deterministic `actor_id_hash` / `ip_hash`. **Required in production** secure config; local may use the package fallback for dev. |
| `OBSERVABILITY_PERSIST_EVENTS` | If `true`, all emitted server events attempt DB insert (see `shouldPersistEvent` in code). If unset, non-production still persists failures, `privileged.operation`, and `security.audit`; production persists broadly per [`packages/logging/src/server.ts`](../../packages/logging/src/server.ts). |
| `OBSERVABILITY_SERVER_CONSOLE` | `full` \| `minimal` \| `off`. Default: `full` outside production, **`minimal` in production** (see [Server sinks](#server-sinks-console-and-database)). |

Turbo passes these through `globalEnv` so tasks invalidate caches when they change.

## Persistence and querying

Persist high-value events to `public.observability_events`.

Purpose:

- app-level incident reconstruction
- security-sensitive mutation auditability
- privileged operation diagnosis
- correlation-centric debugging

Important indexes:

- `timestamp desc`
- `trace_id`
- `correlation_id`
- `(event_family, event_name, timestamp desc)`
- `(outcome, timestamp desc)`
- `actor_id_hash`
- `(service, component, timestamp desc)`

Persistence failures must never fail the business request.

Query patterns to support:

- all events for one `correlation_id`
- all failures for one `trace_id`
- recent privileged operations for a hashed actor
- all failures for `component = user_access.sync`

## Edge Function rules

No Edge Functions exist in the repo today, but new ones must follow this model:

- import from `@workspace/logging/edge`
- derive correlation from request headers
- emit one canonical `edge.request` success or failure event
- apply the same redaction and hashing rules as server code
- use the shared event store when the sink is enabled

Do not create parallel helper files inside `supabase/functions/*`.

## Privileged operation rules

Any service-role or admin-style mutation must emit `privileged.operation` or `security.audit`.

Minimum required metadata:

- target actor hash
- operation name
- outcome
- failure phase when failing
- role or permission summary when relevant

Current highest-priority privileged surface:

- [`packages/supabase-data/src/actions/user-access/sync-user-access.ts`](../packages/supabase-data/src/actions/user-access/sync-user-access.ts)

## Example: server action with context (success and failure)

```typescript
import { headers } from "next/headers";

import {
  createServerObservabilityContext,
  logServerEvent,
  withServerObservabilityContext,
} from "@workspace/logging/server";

export async function exampleAction() {
  const headerList = await headers();
  const ctx = await createServerObservabilityContext({
    headers: headerList,
    requestPath: "/example",
  });

  return withServerObservabilityContext(ctx, async () => {
    try {
      // ... work ...
      await logServerEvent({
        actorId: userId,
        actorType: "user",
        component: "example.action",
        eventFamily: "action.lifecycle",
        eventName: "example_completed",
        metadata: { row_count: 1 },
        operation: "exampleAction",
        operationType: "action",
        outcome: "success",
        persist: true,
        service: "example-app",
      });
      return { ok: true };
    } catch (error) {
      await logServerEvent({
        actorId: userId,
        component: "example.action",
        error,
        eventFamily: "action.lifecycle",
        eventName: "example_failed",
        metadata: { failure_phase: "repository" },
        operation: "exampleAction",
        operationType: "action",
        outcome: "failure",
        persist: true,
        service: "example-app",
      });
      throw error;
    }
  });
}
```

Adjust `headers` / `userId` to your app’s auth and request helpers.

## Implementation status note

This document defines the target standard. Adoption is incremental, but every new logging or observability change must move toward this contract rather than inventing a side path.
