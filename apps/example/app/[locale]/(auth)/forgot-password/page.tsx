import { Link } from "@/i18n/navigation"

import { ForgotPasswordForm } from "@/app/[locale]/(auth)/_components/forgot-password-form"
import { AuthSplitShell } from "@/app/[locale]/(auth)/_components/auth-split-shell"
import { authPageMainClass } from "@/app/[locale]/(auth)/_lib/auth-page-classes"
import {
  resolveAuthSearchParams,
  type AuthSearchParams,
} from "@/app/[locale]/(auth)/_lib/auth-search-params"

type ForgotPasswordPageProps = {
  searchParams: AuthSearchParams
}

export default async function ForgotPasswordPage({
  searchParams,
}: ForgotPasswordPageProps) {
  const { redirectTo } = await resolveAuthSearchParams(searchParams)

  return (
    <main className={authPageMainClass}>
      <AuthSplitShell>
        <div className="w-full max-w-md space-y-6">
          <div className="space-y-2">
            <h1 className="text-2xl font-semibold tracking-tight text-foreground">
              Recuperar palavra-passe
            </h1>
            <p className="text-sm text-muted-foreground">
              Enviaremos um e-mail de recuperação que volta à aplicação para
              concluir a alteração em segurança.
            </p>
          </div>
          <ForgotPasswordForm redirectTo={redirectTo} />
          <p className="text-center text-sm text-muted-foreground">
            Lembrou-se da palavra-passe?{" "}
            <Link
              className="font-medium text-[#4F6EF7] underline underline-offset-4"
              href={`/sign-in?redirect_to=${encodeURIComponent(redirectTo)}`}
            >
              Voltar ao início de sessão
            </Link>
          </p>
        </div>
      </AuthSplitShell>
    </main>
  )
}
