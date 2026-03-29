"use client"

import * as React from "react"

import { ThemeProvider } from "@workspace/brand/components/theme-provider"
import { Toaster } from "@workspace/ui/components/sonner"
import { TooltipProvider } from "@workspace/ui/components/tooltip"

/**
 * Root providers for the example app (theme, tooltips, toasts).
 * Add segment-specific providers in the relevant `layout.tsx` only when needed.
 */
export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider>
      <TooltipProvider delayDuration={0}>
        {children}
        <Toaster />
      </TooltipProvider>
    </ThemeProvider>
  )
}
