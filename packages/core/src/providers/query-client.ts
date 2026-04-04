import { QueryClient } from "@tanstack/react-query"

/**
 * React Query client configuration for SSR-optimized applications.
 *
 * ## Configuration Rationale
 *
 * These defaults prevent common SSR/SSG pitfalls:
 *
 * - **staleTime: 60s** — Data hydrated from the server is considered fresh for 1 minute.
 *   Prevents immediate refetch on client hydration (server already fetched).
 *
 * - **gcTime: 5m** — Keep unused data in memory for 5 minutes.
 *   Enables instant navigation back to previous pages without refetch.
 *
 * - **retry: 1** — Only retry failed queries once (default is 3).
 *   Reduces noise in production logs and prevents retry storms.
 *
 * - **refetchOnWindowFocus: false** — Do not refetch when the window regains focus.
 *   SSR apps handle freshness server-side; client-side refetches are redundant.
 *
 * @see https://tanstack.com/query/latest/docs/react/guides/important-defaults
 */
export function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000,
        gcTime: 5 * 60 * 1000,
        retry: 1,
        refetchOnWindowFocus: false,
      },
    },
  })
}

let browserQueryClient: ReturnType<typeof createQueryClient> | undefined = undefined

/**
 * Singleton React Query client for the browser (SSR-safe).
 */
export function getBrowserQueryClient() {
  if (typeof window === "undefined") {
    return createQueryClient()
  }

  if (!browserQueryClient) {
    browserQueryClient = createQueryClient()
  }
  return browserQueryClient
}
