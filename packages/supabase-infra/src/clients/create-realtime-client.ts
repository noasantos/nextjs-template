/**
 * Create Supabase realtime client
 *
 * Used for Realtime subscriptions and presence channels.
 * This client is optimized for real-time features like:
 * - Chat messages
 * - Presence tracking
 * - Live updates
 * - Broadcast events
 *
 * ## Features
 *
 * - **WebSocket connection**: Maintains persistent connection
 * - **Presence channels**: Track online users
 * - **Broadcast**: Send messages to all clients
 * - **Postgres changes**: Listen to DB changes in real-time
 *
 * ## Usage
 *
 * ```typescript
 * import { createRealtimeClient } from "@workspace/supabase-infra/clients/realtime"
 *
 * const realtimeClient = createRealtimeClient()
 *
 * // Subscribe to a channel
 * const channel = realtimeClient.channel("room:123")
 *
 * // Listen to broadcast messages
 * channel.on("broadcast", { event: "message" }, (payload) => {
 *   console.log("Message received:", payload)
 * })
 *
 * // Subscribe
 * channel.subscribe((status) => {
 *   if (status === "SUBSCRIBED") {
 *     console.log("Successfully subscribed")
 *   }
 * })
 * ```
 *
 * ## Realtime Features
 *
 * ### Broadcast
 *
 * Send messages to all clients in a channel:
 *
 * ```typescript
 * channel.send({
 *   type: "broadcast",
 *   event: "message",
 *   payload: { text: "Hello!" }
 * })
 * ```
 *
 * ### Presence
 *
 * Track online users:
 *
 * ```typescript
 * channel.on("presence", { event: "sync" }, () => {
 *   const state = channel.presenceState()
 *   console.log("Online users:", state)
 * })
 *
 * channel.track({ user_id: "123", name: "John" })
 * ```
 *
 * ### Postgres Changes
 *
 * Listen to database changes:
 *
 * ```typescript
 * channel.on(
 *   "postgres_changes",
 *   {
 *     event: "*",
 *     schema: "public",
 *     table: "messages"
 *   },
 *   (payload) => {
 *     console.log("DB change:", payload)
 *   }
 * )
 * ```
 *
 * ## Singleton Pattern
 *
 * Uses singleton pattern to maintain single WebSocket connection:
 *
 * ```typescript
 * const client1 = createRealtimeClient()
 * const client2 = createRealtimeClient()
 *
 * client1 === client2 // true (same instance)
 * ```
 *
 * @returns Typed Supabase realtime client
 * @see https://supabase.com/docs/guides/realtime
 *
 * @module @workspace/supabase-infra/clients/realtime
 */
import { createClient } from "@supabase/supabase-js"

import { getSupabasePublicEnv } from "@workspace/supabase-infra/env/public"
import type { Database } from "@workspace/supabase-infra/types/database.types"

/**
 * Cached realtime client instance (singleton)
 */
let cachedClient: ReturnType<typeof createClient<Database>> | null = null

/**
 * Create or retrieve cached realtime client
 *
 * Uses singleton pattern to maintain single WebSocket connection.
 * Multiple calls return the same client instance.
 *
 * @returns Typed Supabase realtime client
 */
export function createRealtimeClient(): ReturnType<typeof createClient<Database>> {
  if (cachedClient) {
    return cachedClient
  }

  const { NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, NEXT_PUBLIC_SUPABASE_URL } = getSupabasePublicEnv()

  cachedClient = createClient<Database>(
    NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      realtime: {
        // Configure realtime behavior
        params: {
          // Maximum events per second (rate limiting)
          eventsPerSecond: 10,
        },
      },
    }
  )

  return cachedClient
}
