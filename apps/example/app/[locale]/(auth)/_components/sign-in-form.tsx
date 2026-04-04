"use client"

import * as React from "react"

import { AuthSubmitFooter } from "@/app/[locale]/(auth)/_components/auth-submit-footer"
import { useAuthErrorTranslator } from "@/app/[locale]/(auth)/_lib/auth-error-message"
import { useAuthFormSchemas } from "@/app/[locale]/(auth)/_lib/auth-form-schemas"
import { Link } from "@/i18n/navigation"
import { FormField, FormFieldError, FormFieldLabel } from "@workspace/forms/components/form-field"
import { useAppForm } from "@workspace/forms/hooks/use-app-form"
import { getFormErrorText } from "@workspace/forms/lib/get-form-error-text"
import { signInWithPassword } from "@workspace/supabase-auth/browser/sign-in-with-password"
import { buildAuthContinueUrl } from "@workspace/supabase-auth/shared/app-destination"
import { Input } from "@workspace/ui/components/input"

type SignInFormProps = {
  redirectTo: string
}

function SignInForm({ redirectTo }: SignInFormProps) {
  const translateAuthError = useAuthErrorTranslator()
  const schemas = useAuthFormSchemas()
  const [authError, setAuthError] = React.useState<string | null>(null)
  const [notice, setNotice] = React.useState<string | null>(null)

  const form = useAppForm({
    defaultValues: schemas.signInDefaultValues,
    formId: "auth-sign-in",
    onSubmit: async ({ value }) => {
      setAuthError(null)
      setNotice(null)

      const { error } = await signInWithPassword(value)

      if (error) {
        setAuthError(translateAuthError(error.message))
        return
      }

      setNotice("Sessão iniciada. A verificar o acesso e a redirecionar…")
      window.location.assign(buildAuthContinueUrl(redirectTo))
    },
    schema: schemas.signInSchema,
  })

  return (
    <div className="w-full max-w-md">
      <header className="mb-8 space-y-1.5">
        <h1 className="text-foreground text-2xl font-semibold tracking-tight">
          Bem-vindo de volta!
        </h1>
        <p className="text-muted-foreground text-sm leading-relaxed text-pretty">
          Por favor, introduza as suas credenciais para iniciar sessão.
        </p>
      </header>

      <form
        className="grid gap-5"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          void form.handleSubmit()
        }}
      >
        <form.Subscribe
          selector={(state) => ({
            canSubmit: state.canSubmit,
            isDirty: state.isDirty,
            isSubmitting: state.isSubmitting,
          })}
        >
          {({ canSubmit, isDirty, isSubmitting }) => (
            <>
              {notice ? (
                <div className="rounded-md border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-xs/relaxed text-emerald-700 dark:text-emerald-300">
                  {notice}
                </div>
              ) : null}
              {authError ? (
                <div className="border-destructive/30 bg-destructive/10 text-destructive rounded-md border px-3 py-2 text-xs/relaxed">
                  {authError}
                </div>
              ) : null}

              <form.Field name="email">
                {(field) => {
                  const invalid = field.state.meta.isTouched && field.state.meta.errors.length > 0
                  const errorMessage = getFormErrorText(field.state.meta.errors)
                  const errorId = `${field.name}-error`

                  return (
                    <FormField invalid={invalid} required>
                      <FormFieldLabel htmlFor={field.name} required>
                        E-mail
                      </FormFieldLabel>
                      <Input
                        aria-describedby={invalid ? errorId : undefined}
                        aria-invalid={invalid}
                        autoComplete="email"
                        className="border-border bg-background h-11 rounded-lg"
                        disabled={isSubmitting}
                        id={field.name}
                        name={field.name}
                        onBlur={field.handleBlur}
                        onChange={(event) => field.handleChange(event.target.value)}
                        placeholder="email@exemplo.com"
                        type="email"
                        value={field.state.value}
                      />
                      <FormFieldError id={errorId}>{errorMessage}</FormFieldError>
                    </FormField>
                  )
                }}
              </form.Field>

              <form.Field name="password">
                {(field) => {
                  const invalid = field.state.meta.isTouched && field.state.meta.errors.length > 0
                  const errorMessage = getFormErrorText(field.state.meta.errors)
                  const errorId = `${field.name}-error`

                  return (
                    <FormField invalid={invalid} required>
                      <FormFieldLabel htmlFor={field.name} required>
                        Palavra-passe
                      </FormFieldLabel>
                      <Input
                        aria-describedby={invalid ? errorId : undefined}
                        aria-invalid={invalid}
                        autoComplete="current-password"
                        className="border-border bg-background h-11 rounded-lg"
                        disabled={isSubmitting}
                        id={field.name}
                        name={field.name}
                        onBlur={field.handleBlur}
                        onChange={(event) => field.handleChange(event.target.value)}
                        placeholder="palavra-passe"
                        type="password"
                        value={field.state.value}
                      />
                      <FormFieldError id={errorId}>{errorMessage}</FormFieldError>
                    </FormField>
                  )
                }}
              </form.Field>

              <AuthSubmitFooter
                canSubmit={canSubmit}
                isDirty={isDirty}
                isSubmitting={isSubmitting}
                showStatusRow={false}
                submitLabel="Iniciar sessão"
                submittingLabel="A iniciar sessão…"
              />

              <div className="-mt-1 text-center">
                <Link
                  className="text-sm font-medium text-[#4F6EF7] underline-offset-4 hover:underline"
                  href={`/forgot-password?redirect_to=${encodeURIComponent(redirectTo)}`}
                >
                  Esqueceu-se da palavra-passe?
                </Link>
              </div>

              <p className="text-muted-foreground text-center text-sm">
                As contas são criadas por administradores. Se precisa de acesso, contacte a equipa
                responsável.
              </p>
            </>
          )}
        </form.Subscribe>
      </form>
    </div>
  )
}

export { SignInForm }
