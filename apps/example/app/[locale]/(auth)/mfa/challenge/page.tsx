import { requireUser } from "@workspace/supabase-auth/session/require-user"
import { getDefaultRedirectTo } from "@workspace/supabase-auth/shared/auth-redirect"

import { MfaChallengeForm } from "@/app/[locale]/(auth)/_components/mfa-challenge-form"
import { AuthSplitShell } from "@/app/[locale]/(auth)/_components/auth-split-shell"
import { authPageMainClass } from "@/app/[locale]/(auth)/_lib/auth-page-classes"
import {
  resolveAuthSearchParams,
  type AuthSearchParams,
} from "@/app/[locale]/(auth)/_lib/auth-search-params"

type MfaChallengePageProps = {
  searchParams: AuthSearchParams
}

export default async function MfaChallengePage({
  searchParams,
}: MfaChallengePageProps) {
  await requireUser()
  const { redirectTo } = await resolveAuthSearchParams(searchParams)

  return (
    <main className={authPageMainClass}>
      <AuthSplitShell>
        <div className="w-full max-w-md space-y-6">
          <div className="space-y-2">
            <h1 className="text-2xl font-semibold tracking-tight text-foreground">
              Verificação MFA
            </h1>
            <p className="text-sm text-muted-foreground">
              Utilize este passo adicional antes de aceder a rotas que exigem{" "}
              <span className="font-mono text-xs">aal2</span>.
            </p>
          </div>
          <MfaChallengeForm redirectTo={redirectTo ?? getDefaultRedirectTo()} />
        </div>
      </AuthSplitShell>
    </main>
  )
}
