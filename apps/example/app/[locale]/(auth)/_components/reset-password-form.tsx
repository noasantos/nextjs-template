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
import { updatePassword } from "@workspace/supabase-auth/browser/update-password"
import { buildAuthContinueUrl } from "@workspace/supabase-auth/shared/app-destination"

import { AuthSubmitFooter } from "@/app/[locale]/(auth)/_components/auth-submit-footer"
import { translateAuthErrorMessage } from "@/app/[locale]/(auth)/_lib/auth-error-message"
import {
  passwordResetDefaultValues,
  passwordResetSchema,
} from "@/app/[locale]/(auth)/_lib/auth-form-schemas"

type ResetPasswordFormProps = {
  redirectTo: string
}

function ResetPasswordForm({ redirectTo }: ResetPasswordFormProps) {
  const [authError, setAuthError] = React.useState<string | null>(null)
  const [notice, setNotice] = React.useState<string | null>(null)

  const form = useAppForm({
    defaultValues: passwordResetDefaultValues,
    formId: "auth-reset-password",
    onSubmit: async ({ value }) => {
      setAuthError(null)
      setNotice(null)

      const { error } = await updatePassword({ password: value.password })

      if (error) {
        setAuthError(translateAuthErrorMessage(error.message))
        return
      }

      setNotice("Palavra-passe atualizada. A redirecionar…")
      window.setTimeout(() => {
        window.location.assign(buildAuthContinueUrl(redirectTo))
      }, 500)
    },
    schema: passwordResetSchema,
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
            {(["password", "confirmPassword"] as const).map((fieldName) => (
              <form.Field key={fieldName} name={fieldName}>
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
                        {field.name === "password"
                          ? "Nova palavra-passe"
                          : "Confirmar palavra-passe"}
                      </FormFieldLabel>
                      <Input
                        aria-describedby={
                          invalid
                            ? `${descriptionId} ${errorId}`
                            : descriptionId
                        }
                        aria-invalid={invalid}
                        autoComplete={
                          field.name === "password" ? "new-password" : "off"
                        }
                        className="h-11 rounded-lg"
                        disabled={isSubmitting}
                        id={field.name}
                        name={field.name}
                        onBlur={field.handleBlur}
                        onChange={(event) =>
                          field.handleChange(event.target.value)
                        }
                        placeholder={
                          field.name === "password"
                            ? "Escolha uma nova palavra-passe"
                            : "Repita a palavra-passe"
                        }
                        type="password"
                        value={field.state.value}
                      />
                      <FormFieldDescription id={descriptionId}>
                        A sessão de recuperação mantém-se ativa na aplicação até
                        concluir a alteração.
                      </FormFieldDescription>
                      <FormFieldError id={errorId}>
                        {errorMessage}
                      </FormFieldError>
                    </FormField>
                  )
                }}
              </form.Field>
            ))}

            <AuthSubmitFooter
              canSubmit={canSubmit}
              isDirty={isDirty}
              isSubmitting={isSubmitting}
              submitLabel="Atualizar palavra-passe"
              submittingLabel="A atualizar…"
            />
          </>
        )}
      </form.Subscribe>
    </form>
  )
}

export { ResetPasswordForm }
