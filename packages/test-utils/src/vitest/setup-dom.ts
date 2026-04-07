import "@testing-library/jest-dom/vitest"
import { cleanup } from "@testing-library/react"
import { afterEach, vi } from "vitest"

const originalEmitWarning = process.emitWarning.bind(process)

process.emitWarning = ((warning: string | Error, ...args: unknown[]) => {
  const warningText = typeof warning === "string" ? warning : warning.message
  if (warningText.includes("--localstorage-file") && warningText.includes("without a valid path")) {
    return
  }

  // @type-escape: Node's overloaded emitWarning signature is broader than this local filter wrapper.
  return originalEmitWarning(warning as never, ...(args as []))
}) as typeof process.emitWarning

afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
  vi.unstubAllEnvs()
  vi.useRealTimers()
})
