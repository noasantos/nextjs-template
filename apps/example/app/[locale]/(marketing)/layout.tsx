import type { ReactNode } from "react"

import { SiteFooter } from "@/components/marketing/site-footer"
import { SiteHeader } from "@/components/marketing/site-header"

import { MarketingThemeLock } from "@/app/[locale]/(marketing)/_components/marketing-theme-lock"

export default function MarketingLayout({
  children,
}: Readonly<{
  children: ReactNode
}>) {
  return (
    <MarketingThemeLock>
      <>
        <SiteHeader />
        <div className="flex min-h-svh flex-col">
          {/* pt-14 = altura do header fixo (h-14) — evita conteúdo por baixo da barra */}
          <main className="flex min-h-0 w-full min-w-0 flex-1 flex-col pt-14">
            {children}
          </main>
          <SiteFooter />
        </div>
      </>
    </MarketingThemeLock>
  )
}
