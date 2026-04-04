"use client"

import { useForm } from "@tanstack/react-form"
import { z } from "zod"

type UseAppFormOptions<TSchema extends z.ZodType> = {
  defaultValues: z.input<TSchema>
  formId?: string
  onSubmit: (props: {
    formApi: unknown
    rawValue: z.input<TSchema>
    value: z.output<TSchema>
  }) => Promise<void> | void
  schema: TSchema
}

function useAppForm<TSchema extends z.ZodType>({
  defaultValues,
  formId,
  onSubmit,
  schema,
}: UseAppFormOptions<TSchema>) {
  return useForm({
    defaultValues,
    ...(formId !== undefined && { formId }),
    validators: {
      onBlur: schema,
      onChange: schema,
      onSubmit: schema,
    },
    onSubmit: async ({ value, formApi }) => {
      const parsedValue = await schema.parseAsync(value)

      await onSubmit({
        formApi,
        rawValue: value,
        value: parsedValue,
      })
    },
  })
}

export { useAppForm }
