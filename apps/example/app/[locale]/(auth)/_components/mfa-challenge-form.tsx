"use client"

import * as React from "react"
import { useRouter } from "next/navigation"

import { Link } from "@/i18n/navigation"

import { Button } from "@workspace/ui/components/button"
import { Input } from "@workspace/ui/components/input"
import {
  FormField,
  FormFieldDescription,
  FormFieldError,
  FormFieldLabel,
} from "@workspace/forms/components/form-field"
import { useAppForm } from "@workspace/forms/hooks/use-app-form"
import { getFormErrorText } from "@workspace/forms/lib/get-form-error-text"
import { getMfaFactors } from "@workspace/supabase-auth/browser/get-mfa-factors"
import { verifyTotpChallenge } from "@workspace/supabase-auth/browser/verify-totp-challenge"

import { AuthSubmitFooter } from "@/app/[locale]/(auth)/_components/auth-submit-footer"
import { translateAuthErrorMessage } from "@/app/[locale]/(auth)/_lib/auth-error-message"
import {
  mfaCodeDefaultValues,
  mfaCodeSchema,
} from "@/app/[locale]/(auth)/_lib/auth-form-schemas"

type MfaChallengeFormProps = {
  redirectTo: string
}

function MfaChallengeForm({ redirectTo }: MfaChallengeFormProps) {
  const router = useRouter()
  const [authError, setAuthError] = React.useState<string | null>(null)
  const [factorId, setFactorId] = React.useState<string>("")
  const [loadingFactors, setLoadingFactors] = React.useState(true)

  React.useEffect(() => {
    async function loadFactors() {
      const { data, error } = await getMfaFactors()

      if (error) {
        setAuthError(translateAuthErrorMessage(error.message))
        setLoadingFactors(false)
        return
      }

      const firstFactor = data.all[0]

      if (firstFactor) {
        setFactorId(firstFactor.id)
      }

      setLoadingFactors(false)
    }

    void loadFactors()
  }, [])

  const form = useAppForm({
    defaultValues: mfaCodeDefaultValues,
    formId: "auth-mfa-challenge",
    onSubmit: async ({ value }) => {
      setAuthError(null)

      if (!factorId) {
        setAuthError("Registe um fator TOTP antes de tentar o desafio MFA.")
        return
      }

      const { error } = await verifyTotpChallenge({
        code: value.code,
        factorId,
      })

      if (error) {
        setAuthError(translateAuthErrorMessage(error.message))
        return
      }

      router.refresh()
      window.location.assign(redirectTo)
    },
    schema: mfaCodeSchema,
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
      {authError ? (
        <div className="rounded-md border border-destructive/30 bg-destructive/10 px-3 py-2 text-xs/relaxed text-destructive">
          {authError}
        </div>
      ) : null}

      <div className="grid gap-2">
        <FormField invalid={!factorId && !loadingFactors} required>
          <FormFieldLabel htmlFor="factor-id" required>
            ID do fator
          </FormFieldLabel>
          <Input
            className="h-11 rounded-lg"
            disabled={loadingFactors}
            id="factor-id"
            onChange={(event) => setFactorId(event.target.value)}
            placeholder="ID do fator verificado"
            value={factorId}
          />
          <FormFieldDescription id="factor-id-description">
            O primeiro fator registado é carregado automaticamente. Substitua o
            valor se precisar de outro fator.
          </FormFieldDescription>
        </FormField>
      </div>

      <form.Subscribe
        selector={(state) => ({
          canSubmit: state.canSubmit,
          isDirty: state.isDirty,
          isSubmitting: state.isSubmitting,
        })}
      >
        {({ canSubmit, isDirty, isSubmitting }) => (
          <>
            <form.Field name="code">
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
                      Código de 6 dígitos
                    </FormFieldLabel>
                    <Input
                      aria-describedby={
                        invalid ? `${descriptionId} ${errorId}` : descriptionId
                      }
                      aria-invalid={invalid}
                      autoComplete="one-time-code"
                      className="h-11 rounded-lg"
                      disabled={isSubmitting}
                      id={field.name}
                      inputMode="numeric"
                      name={field.name}
                      onBlur={field.handleBlur}
                      onChange={(event) =>
                        field.handleChange(event.target.value)
                      }
                      placeholder="123456"
                      value={field.state.value}
                    />
                    <FormFieldDescription id={descriptionId}>
                      Introduza o código temporário da aplicação de autenticação
                      que registou.
                    </FormFieldDescription>
                    <FormFieldError id={errorId}>{errorMessage}</FormFieldError>
                  </FormField>
                )
              }}
            </form.Field>

            <AuthSubmitFooter
              canSubmit={canSubmit && Boolean(factorId)}
              isDirty={isDirty}
              isSubmitting={isSubmitting}
              submitLabel="Verificar fator"
              submittingLabel="A verificar…"
            />
          </>
        )}
      </form.Subscribe>

      <Button asChild type="button" variant="ghost">
        <Link href="/mfa">Voltar às definições MFA</Link>
      </Button>
    </form>
  )
}

export { MfaChallengeForm }
