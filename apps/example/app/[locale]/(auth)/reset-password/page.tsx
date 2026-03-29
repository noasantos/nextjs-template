import { requireUser } from "@workspace/supabase-auth/session/require-user"

import { ResetPasswordForm } from "@/app/[locale]/(auth)/_components/reset-password-form"
import { AuthSplitShell } from "@/app/[locale]/(auth)/_components/auth-split-shell"
import { authPageMainClass } from "@/app/[locale]/(auth)/_lib/auth-page-classes"
import {
  resolveAuthSearchParams,
  type AuthSearchParams,
} from "@/app/[locale]/(auth)/_lib/auth-search-params"

type ResetPasswordPageProps = {
  searchParams: AuthSearchParams
}

export default async function ResetPasswordPage({
  searchParams,
}: ResetPasswordPageProps) {
  await requireUser()
  const { redirectTo } = await resolveAuthSearchParams(searchParams)

  return (
    <main className={authPageMainClass}>
      <AuthSplitShell>
        <div className="w-full max-w-md space-y-6">
          <div className="space-y-2">
            <h1 className="text-2xl font-semibold tracking-tight text-foreground">
              Definir nova palavra-passe
            </h1>
            <p className="text-sm text-muted-foreground">
              A sessão de recuperação é validada no servidor antes de esta
              página ser mostrada.
            </p>
          </div>
          <ResetPasswordForm redirectTo={redirectTo} />
        </div>
      </AuthSplitShell>
    </main>
  )
}
