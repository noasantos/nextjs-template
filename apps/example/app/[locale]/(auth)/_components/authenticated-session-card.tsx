import { Link } from "@/i18n/navigation"

import { Button } from "@workspace/ui/components/button"
import type { AuthRole } from "@workspace/supabase-auth/shared/auth-role"
import { buildAuthContinueUrl } from "@workspace/supabase-auth/shared/app-destination"
import { buildAuthLogoutUrl } from "@workspace/supabase-auth/shared/auth-redirect"

type AuthenticatedClaims = {
  app_metadata?: Record<string, unknown>
  email?: string | null
  sub: string
  user_metadata?: Record<string, unknown>
}

type AuthenticatedSessionCardProps = {
  claims: AuthenticatedClaims
  redirectTo: string
  roles: readonly AuthRole[]
  userEmail: string
}

function AuthenticatedSessionCard({
  claims,
  redirectTo,
  roles,
  userEmail,
}: AuthenticatedSessionCardProps) {
  return (
    <div className="w-full max-w-md space-y-6">
      <div className="space-y-2">
        <h1 className="text-2xl font-semibold tracking-tight text-foreground">
          Sessão autenticada
        </h1>
        <p className="text-sm text-muted-foreground">
          Já tem sessão iniciada através dos helpers SSR partilhados.
        </p>
      </div>

      <div className="rounded-xl border border-border bg-zinc-100 px-4 py-3 text-sm dark:bg-zinc-900/50">
        <div className="font-medium">{userEmail}</div>
        <div className="text-xs/relaxed text-muted-foreground">
          Identificador: {claims.sub}
        </div>
        <div className="text-xs/relaxed text-muted-foreground">
          Funções: {roles.length > 0 ? roles.join(", ") : "nenhuma atribuída"}
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        <Button asChild className="h-10 rounded-lg">
          <a href={buildAuthContinueUrl(redirectTo)}>
            Voltar ao espaço de trabalho
          </a>
        </Button>
        <Button asChild variant="outline">
          <Link href="/mfa">Gerir MFA</Link>
        </Button>
        <Button asChild variant="outline">
          <a href={buildAuthLogoutUrl(redirectTo)}>Terminar sessão</a>
        </Button>
      </div>
    </div>
  )
}

export { AuthenticatedSessionCard }
