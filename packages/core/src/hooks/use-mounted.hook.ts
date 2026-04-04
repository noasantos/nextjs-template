"use client"

import * as React from "react"

/**
 * useMounted hook - prevents hydration mismatches
 *
 * Returns `true` when component is mounted on client, `false` during SSR.
 * Use this to conditionally render client-only features.
 *
 * @example
 * ```tsx
 * function MyComponent() {
 *   const mounted = useMounted()
 *
 *   // During SSR: returns null
 *   // After hydration: returns <div>Client content</div>
 *   if (!mounted) return null
 *
 *   return <div>Client content</div>
 * }
 * ```
 *
 * @see https://react.dev/reference/react/useEffect#rendering-different-content-on-the-server-and-the-client
 */
export function useMounted() {
  const [mounted, setMounted] = React.useState(false)

  React.useEffect(() => {
    setMounted(true)
  }, [])

  return mounted
}
