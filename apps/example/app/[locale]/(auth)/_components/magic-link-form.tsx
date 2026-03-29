"use client"

import * as React from "react"

import { Input } from "@workspace/ui/components/input"
import {
  FormField,
  FormFieldDescription,
  FormFieldError,
  FormFieldLabel,
} from "@workspace/forms/components/form-field"
import { useAppForm } from "@workspace/forms/hooks/use-app-form"
import { getFormErrorText } from "@workspace/forms/lib/get-form-error-text"
import { signInWithMagicLink } from "@workspace/supabase-auth/browser/sign-in-with-magic-link"

import { AuthSubmitFooter } from "@/app/[locale]/(auth)/_components/auth-submit-footer"
import { translateAuthErrorMessage } from "@/app/[locale]/(auth)/_lib/auth-error-message"
import {
  emailDefaultValues,
  emailSchema,
} from "@/app/[locale]/(auth)/_lib/auth-form-schemas"

type MagicLinkFormProps = {
  redirectTo: string
}

function MagicLinkForm({ redirectTo }: MagicLinkFormProps) {
  const [authError, setAuthError] = React.useState<string | null>(null)
  const [notice, setNotice] = React.useState<string | null>(null)

  const form = useAppForm({
    defaultValues: emailDefaultValues,
    formId: "auth-magic-link",
    onSubmit: async ({ value }) => {
      setAuthError(null)
      setNotice(null)

      const { error } = await signInWithMagicLink({
        email: value.email,
        redirectTo,
      })

      if (error) {
        setAuthError(translateAuthErrorMessage(error.message))
        return
      }

      setNotice(
        "Ligação enviada. Conclua o início de sessão a partir do e-mail, neste browser e dispositivo."
      )
    },
    schema: emailSchema,
  })

  return (
    <form
      className="grid gap-5"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        void form.handleSubmit()
      }}
    >
      {notice ? (
        <div className="rounded-md border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-xs/relaxed text-emerald-700 dark:text-emerald-300">
          {notice}
        </div>
      ) : null}
      {authError ? (
        <div className="rounded-md border border-destructive/30 bg-destructive/10 px-3 py-2 text-xs/relaxed text-destructive">
          {authError}
        </div>
      ) : null}

      <form.Subscribe
        selector={(state) => ({
          canSubmit: state.canSubmit,
          isDirty: state.isDirty,
          isSubmitting: state.isSubmitting,
        })}
      >
        {({ canSubmit, isDirty, isSubmitting }) => (
          <>
            <form.Field name="email">
              {(field) => {
                const invalid =
                  field.state.meta.isTouched &&
                  field.state.meta.errors.length > 0
                const errorMessage = getFormErrorText(field.state.meta.errors)
                const descriptionId = `${field.name}-description`
                const errorId = `${field.name}-error`

                return (
                  <FormField invalid={invalid} required>
                    <FormFieldLabel htmlFor={field.name} required>
                      E-mail
                    </FormFieldLabel>
                    <Input
                      aria-describedby={
                        invalid ? `${descriptionId} ${errorId}` : descriptionId
                      }
                      aria-invalid={invalid}
                      autoComplete="email"
                      className="h-11 rounded-lg"
                      disabled={isSubmitting}
                      id={field.name}
                      name={field.name}
                      onBlur={field.handleBlur}
                      onChange={(event) =>
                        field.handleChange(event.target.value)
                      }
                      placeholder="nome@organizacao.org"
                      type="email"
                      value={field.state.value}
                    />
                    <FormFieldDescription id={descriptionId}>
                      Apenas início de sessão: não são criadas contas novas por
                      este fluxo.
                    </FormFieldDescription>
                    <FormFieldError id={errorId}>{errorMessage}</FormFieldError>
                  </FormField>
                )
              }}
            </form.Field>

            <AuthSubmitFooter
              canSubmit={canSubmit}
              isDirty={isDirty}
              isSubmitting={isSubmitting}
              submitLabel="Enviar ligação mágica"
              submittingLabel="A enviar…"
            />
          </>
        )}
      </form.Subscribe>
    </form>
  )
}

export { MagicLinkForm }
