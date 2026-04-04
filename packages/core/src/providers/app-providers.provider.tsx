"use client"

import { QueryClientProvider, type QueryClient } from "@tanstack/react-query"
import * as React from "react"

import { ThemeProvider } from "@workspace/core/components/theme-provider"
import { Toaster } from "@workspace/ui/components/sonner"
import { TooltipProvider } from "@workspace/ui/components/tooltip"

import { getBrowserQueryClient } from "./query-client"

/**
 * Root application providers for Next.js apps (React Query, theme, tooltips, toasts).
 *
 * Lives in `@workspace/core` so all apps share one implementation. App-specific
 * wrappers belong under `apps/<name>/` only when they add behaviour unique to that app.
 *
 * @see docs/architecture/core-package.md
 */
export function AppProviders({
  children,
  queryClient,
}: {
  children: React.ReactNode
  queryClient?: QueryClient
}) {
  const internalQueryClient = queryClient ?? getBrowserQueryClient()

  return (
    <QueryClientProvider client={internalQueryClient}>
      <ThemeProvider>
        <TooltipProvider delayDuration={0}>
          {children}
          <Toaster />
        </TooltipProvider>
      </ThemeProvider>
    </QueryClientProvider>
  )
}
