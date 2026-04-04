"use client"

import { ThemeProvider as NextThemesProvider, useTheme } from "next-themes"
import * as React from "react"

/**
 * Theme provider with system theme detection and hotkey toggle.
 *
 * Features:
 * - Automatic system theme detection
 * - Persisted theme preference
 * - Keyboard shortcut: Press 'd' to toggle (when not typing)
 * - Smooth transitions between themes
 *
 * @example
 * ```tsx
 * // In your root layout
 * import { ThemeProvider } from '@workspace/core/components'
 *
 * export default function RootLayout({ children }) {
 *   return (
 *     <ThemeProvider>
 *       {children}
 *     </ThemeProvider>
 *   )
 * }
 * ```
 *
 * @example
 * ```tsx
 * // Manual theme toggle button
 * import { useTheme } from '@workspace/core/components'
 *
 * function ThemeToggle() {
 *   const { theme, setTheme } = useTheme()
 *
 *   return (
 *     <button onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
 *       Toggle theme
 *     </button>
 *   )
 * }
 * ```
 */
function ThemeProvider({ children, ...props }: React.ComponentProps<typeof NextThemesProvider>) {
  return (
    <NextThemesProvider
      attribute="class"
      defaultTheme="system"
      enableSystem
      disableTransitionOnChange
      {...props}
    >
      <ThemeHotkey />
      {children}
    </NextThemesProvider>
  )
}

function isTypingTarget(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) {
    return false
  }

  return (
    target.isContentEditable ||
    target.tagName === "INPUT" ||
    target.tagName === "TEXTAREA" ||
    target.tagName === "SELECT"
  )
}

function ThemeHotkey() {
  const { resolvedTheme, setTheme } = useTheme()

  React.useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (event.defaultPrevented || event.repeat) {
        return
      }

      if (event.metaKey || event.ctrlKey || event.altKey) {
        return
      }

      if (event.key.toLowerCase() !== "d") {
        return
      }

      if (isTypingTarget(event.target)) {
        return
      }

      setTheme(resolvedTheme === "dark" ? "light" : "dark")
    }

    window.addEventListener("keydown", onKeyDown)

    return () => {
      window.removeEventListener("keydown", onKeyDown)
    }
  }, [resolvedTheme, setTheme])

  return null
}

export { ThemeProvider, useTheme }
