"use client"

import { zodResolver } from "@hookform/resolvers/zod"
import {
  useHookFormAction,
  type UseHookFormActionHookReturn,
} from "@next-safe-action/adapter-react-hook-form/hooks"
import type { SingleInputActionFn } from "next-safe-action/hooks"
import type { DefaultValues, FieldValues, Resolver } from "react-hook-form"
import type { z, ZodTypeAny } from "zod"

type FormValues<TSchema extends ZodTypeAny> = z.input<TSchema> & FieldValues

type UseActionFormOptions<
  TSchema extends ZodTypeAny,
  TServerError,
  TShapedErrors,
  TData,
  TAction extends SingleInputActionFn<TServerError, TSchema, TShapedErrors, TData>,
> = {
  action: TAction
  schema: TSchema
  defaultValues: DefaultValues<FormValues<TSchema>>
  values?: FormValues<TSchema>
  onSuccess?: (data: NonNullable<TData>) => void
  onError?: (error: TServerError | undefined) => void
}

function createResolver<TSchema extends ZodTypeAny>(
  schema: TSchema
): Resolver<FormValues<TSchema>, unknown, z.output<TSchema>> {
  return (zodResolver as (...args: unknown[]) => unknown)(schema) as Resolver<
    FormValues<TSchema>,
    unknown,
    z.output<TSchema>
  >
}

function useActionForm<
  TSchema extends ZodTypeAny,
  TServerError,
  TShapedErrors,
  TData,
  TAction extends SingleInputActionFn<TServerError, TSchema, TShapedErrors, TData>,
>({
  action,
  schema,
  defaultValues,
  values,
  onSuccess,
  onError,
}: UseActionFormOptions<
  TSchema,
  TServerError,
  TShapedErrors,
  TData,
  TAction
>): UseHookFormActionHookReturn<TServerError, TSchema, TShapedErrors, TData> {
  // @type-escape: Resolver<z.input<TSchema>&FieldValues,…> is not assignable to Resolver<InferInputOrDefault<TSchema,any>,…> — Standard Schema interface vs Zod method derivation paths diverge
  return useHookFormAction(action, createResolver(schema) as never, {
    actionProps: {
      onSuccess: ({ data }: { data: TData | undefined }) => {
        if (data !== undefined) {
          onSuccess?.(data as NonNullable<TData>)
        }
      },
      onError: ({ error }: { error?: { serverError?: TServerError } }) =>
        onError?.(error?.serverError),
    },
    formProps: {
      // @type-escape: z.input<TSchema> & FieldValues is not provably equal to InferInputOrDefault<TSchema,any> — divergent derivation paths (Zod method vs Standard Schema interface)
      defaultValues: defaultValues as never,
      // @type-escape: same as defaultValues — FormValues<TSchema> not assignable to InferInputOrDefault<TSchema,any> at controlled-values path
      ...(values !== undefined && { values: values as never }),
    },
  })
}

export { useActionForm }
export type { UseActionFormOptions }
