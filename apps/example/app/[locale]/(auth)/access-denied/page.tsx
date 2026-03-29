import { Link } from "@/i18n/navigation"

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@workspace/ui/components/card"
import { getUserRoles } from "@workspace/supabase-auth/session/get-user-roles"

import { authPageMainClass } from "@/app/[locale]/(auth)/_lib/auth-page-classes"
import {
  resolveAuthSearchParams,
  type AuthSearchParams,
} from "@/app/[locale]/(auth)/_lib/auth-search-params"

type AccessDeniedPageProps = {
  searchParams: AuthSearchParams
}

export default async function AccessDeniedPage({
  searchParams,
}: AccessDeniedPageProps) {
  const roles = await getUserRoles()
  const { redirectTo, required } = await resolveAuthSearchParams(searchParams)

  return (
    <main className={authPageMainClass}>
      <Card className="w-full max-w-md rounded-2xl border border-border shadow-none">
        <CardHeader>
          <CardTitle>Acesso recusado</CardTitle>
          <CardDescription>
            A sessão está autenticada, mas não tem as funções necessárias para o
            espaço de trabalho pedido.
          </CardDescription>
        </CardHeader>
        <CardContent className="grid gap-4 text-sm">
          <div className="rounded-md border border-border/60 bg-background px-3 py-2">
            <div className="font-medium">Requisitos de acesso</div>
            <div className="text-xs/relaxed text-muted-foreground">
              {required ?? "Não especificado"}
            </div>
          </div>
          <div className="rounded-md border border-border/60 bg-background px-3 py-2">
            <div className="font-medium">Acesso carregado na sessão</div>
            <div className="text-xs/relaxed text-muted-foreground">
              {roles.length > 0
                ? roles.join(", ")
                : "Nenhuma função de aplicação na sessão."}
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <Link
              className="text-foreground underline underline-offset-4"
              href={`/sign-in?redirect_to=${encodeURIComponent(redirectTo)}`}
            >
              Iniciar sessão com outro utilizador
            </Link>
            <a
              className="text-foreground underline underline-offset-4"
              href={redirectTo}
            >
              Voltar ao destino pedido
            </a>
          </div>
        </CardContent>
      </Card>
    </main>
  )
}
