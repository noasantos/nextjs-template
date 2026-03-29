import { Link } from "@/i18n/navigation"
import { redirect } from "next/navigation"

import { getAccess } from "@workspace/supabase-auth/session/get-access"
import { getClaims } from "@workspace/supabase-auth/session/get-claims"
import {
  getContinueDecision,
  type AppDestination,
} from "@workspace/supabase-auth/shared/app-destination"
import { buildAuthSignInUrl } from "@workspace/supabase-auth/shared/auth-redirect"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@workspace/ui/components/card"

import { authPageMainClass } from "@/app/[locale]/(auth)/_lib/auth-page-classes"
import {
  resolveAuthSearchParams,
  type AuthSearchParams,
} from "@/app/[locale]/(auth)/_lib/auth-search-params"

type ContinuePageProps = {
  searchParams: AuthSearchParams
}

function DestinationLinks({
  destinations,
}: {
  destinations: AppDestination[]
}) {
  return (
    <div className="grid gap-3">
      {destinations.map((destination) => (
        <Link
          key={destination.href}
          className="rounded-xl border border-border bg-background px-4 py-3 text-sm transition-colors hover:bg-muted/50"
          href={destination.href}
        >
          <div className="font-medium">{destination.label}</div>
          <div className="text-xs text-muted-foreground">
            {destination.href}
          </div>
        </Link>
      ))}
    </div>
  )
}

export default async function ContinuePage({
  searchParams,
}: ContinuePageProps) {
  const { redirectTo } = await resolveAuthSearchParams(searchParams)
  const claims = await getClaims()

  if (!claims?.sub) {
    redirect(buildAuthSignInUrl(redirectTo))
  }

  const access = await getAccess(claims)

  const decision = getContinueDecision({
    redirectTo,
    roles: access.roles,
  })

  if (decision.kind === "redirect" || decision.kind === "access-denied") {
    redirect(decision.href)
  }

  return (
    <main className={authPageMainClass}>
      <Card className="w-full max-w-xl rounded-2xl border border-border shadow-none">
        <CardHeader>
          <CardTitle>Escolha o espaço de trabalho</CardTitle>
          <CardDescription>
            A sessão tem acesso a vários espaços. Escolha para onde quer
            continuar.
          </CardDescription>
        </CardHeader>
        <CardContent className="grid gap-4">
          <DestinationLinks destinations={decision.destinations} />
        </CardContent>
      </Card>
    </main>
  )
}
