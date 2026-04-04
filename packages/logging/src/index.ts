/**
 * Client-side logging utilities
 *
 * This package provides structured logging for both client and server-side operations.
 *
 * ## Architecture
 *
 * ```
 * ┌─────────────────────────────────────────┐
 * │           Apps Layer (apps/web)         │
 * │   - UI Components                       │
 * │   - Pages                               │
 * │   - Client Components                   │
 * │   ✅ Client logging only                │
 * └─────────────────────────────────────────┘
 *                    ↓
 * ┌─────────────────────────────────────────┐
 * │      Data Layer (@workspace/supabase-data) │
 * │   - Server Actions ✅                    │
 * │   - Repositories ✅                      │
 * │   - Business Logic ✅                    │
 * │   - Server logging calls                 │
 * └─────────────────────────────────────────┘
 *                    ↓
 * ┌─────────────────────────────────────────┐
 * │      Auth Layer (@workspace/supabase-auth) │
 * │   - Auth guards ✅                       │
 * │   - Session management ✅                │
 * │   - Security logging ✅                  │
 * └─────────────────────────────────────────┘
 *                    ↓
 * ┌─────────────────────────────────────────┐
 * │      Infra Layer (@workspace/supabase-infra) │
 * │   - Database clients ✅                  │
 * │   - Infra logging ✅                     │
 * └─────────────────────────────────────────┘
 * ```
 *
 * ## Module Exports
 *
 * **Client logging** (for browser code):
 * - `@workspace/logging/client` - Client-side logging with "use client"
 *
 * **Server logging** (for server code only):
 * - `@workspace/logging/server` - Server-side logging with "server-only"
 * - `@workspace/logging/server-error` - Server error handling
 * - `@workspace/logging/server-console-sink` - Console sink for development
 *
 * **Shared utilities**:
 * - `@workspace/logging/correlation` - Correlation ID extraction
 * - `@workspace/logging/contracts` - Type definitions
 * - `@workspace/logging/redaction` - Data redaction utilities
 * - `@workspace/logging/errors` - Error handling utilities
 *
 * ## When to Use Client Logging
 *
 * **Use client logging for:**
 * - ✅ User interactions (clicks, form submissions)
 * - ✅ Client-side errors (React errors, API failures)
 * - ✅ Performance metrics (page load, render time)
 * - ✅ Analytics events (page views, feature usage)
 *
 * **Do NOT use client logging for:**
 * - ❌ Server-side operations (use `@workspace/logging/server`)
 * - ❌ Sensitive data (passwords, tokens)
 * - ❌ High-frequency events (use sampling)
 *
 * ## Usage Example
 *
 * ```typescript
 * // ✅ CORRECT - Client Component with logging
 * // apps/web/app/dashboard/page.tsx
 * "use client"
 *
 * import { logClientEvent } from "@workspace/logging/client"
 *
 * export function Dashboard() {
 *   const handleClick = async () => {
 *     await logClientEvent({
 *       component: "dashboard",
 *       eventFamily: "ui.event",
 *       eventName: "button_clicked",
 *       outcome: "success",
 *       metadata: { buttonType: "submit" },
 *     })
 *   }
 *
 *   return <button onClick={handleClick}>Click me</button>
 * }
 * ```
 *
 * @see {@link logClientEvent} - Main client logging function
 * @see {@link logServerEvent} - Server-side logging (use in Server Actions)
 *
 * @module @workspace/logging
 */

// Re-export client logging
export { logClientEvent, logClientError, logUserInteraction } from "./client"

// Re-export client types
export type { ClientEventInput } from "./client"

// Re-export shared utilities (client-safe)
export {
  extractCorrelationFromHeaders,
  applyCorrelationHeaders,
  generateCorrelationId,
  getCorrelationContext,
  withCorrelationContext,
} from "./correlation"

export type { CorrelationContext } from "./correlation"

// Re-export contracts (types only)
export type { EventFamily, Outcome, OperationType, Severity, ErrorCategory } from "./contracts"

// Re-export error utilities
export { getErrorMessage, getErrorCode, categorizeError, serializeUnknownError } from "./errors"

export type { SerializableError } from "./errors"
