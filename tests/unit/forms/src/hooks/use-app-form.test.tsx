import { act, renderHook } from "@testing-library/react"
import { describe, expect, it, vi } from "vitest"
import { z } from "zod"

import { useAppForm } from "@workspace/forms/hooks/use-app-form"

describe("useAppForm", () => {
  it("wires the schema validators and passes parsed values to onSubmit", async () => {
    const onSubmit = vi.fn()
    const schema = z.object({
      email: z
        .string()
        .trim()
        .email()
        .transform((value) => value.toLowerCase()),
    })

    const { result } = renderHook(() =>
      useAppForm({
        defaultValues: {
          email: "USER@example.test",
        },
        formId: "test-form",
        onSubmit,
        schema,
      })
    )

    expect(result.current.options?.validators?.onSubmit).toBe(schema)

    await act(async () => {
      await result.current.options?.onSubmit?.({
        formApi: { reset: vi.fn() },
        value: { email: "USER@example.test" },
      } as never)
    })

    expect(onSubmit).toHaveBeenCalledWith({
      formApi: { reset: expect.any(Function) },
      rawValue: { email: "USER@example.test" },
      value: { email: "user@example.test" },
    })
  })
})
