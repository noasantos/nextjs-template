import { requireUser } from "@workspace/supabase-auth/session/require-user"

import { MfaManagementCard } from "@/app/[locale]/(auth)/_components/mfa-management-card"
import { AuthSplitShell } from "@/app/[locale]/(auth)/_components/auth-split-shell"
import { authPageMainClass } from "@/app/[locale]/(auth)/_lib/auth-page-classes"

export default async function MfaPage() {
  await requireUser()

  return (
    <main className={authPageMainClass}>
      <AuthSplitShell>
        <div className="w-full max-w-2xl space-y-4">
          <div className="space-y-2">
            <h1 className="text-2xl font-semibold tracking-tight text-foreground">
              Autenticação multifator
            </h1>
            <p className="text-sm text-muted-foreground">
              Comece por fatores TOTP: registe uma aplicação de autenticação e
              confirme antes de exigir{" "}
              <span className="font-mono text-xs">aal2</span> nas rotas.
            </p>
          </div>
          <MfaManagementCard />
        </div>
      </AuthSplitShell>
    </main>
  )
}
