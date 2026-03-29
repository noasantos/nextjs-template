import type { Metadata } from "next"
import { getTranslations } from "next-intl/server"

import { Button } from "@workspace/ui/components/button"

import { Link } from "@/i18n/navigation"
import { getSiteUrl } from "@/lib/site-url"

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>
}): Promise<Metadata> {
  const { locale } = await params
  const t = await getTranslations({ locale, namespace: "Metadata" })
  return {
    title: t("title"),
  }
}

export default async function MarketingHomePage() {
  const t = await getTranslations("Marketing")
  const siteOrigin = getSiteUrl()
  const organizationJsonLd = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: t("jsonLdOrganizationName"),
    url: new URL("/", `${siteOrigin}/`).href,
  }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(organizationJsonLd),
        }}
      />
      <div className="flex flex-1 flex-col">
        <section className="flex flex-1 flex-col justify-center px-4 py-24 sm:px-6">
          <div className="mx-auto max-w-2xl text-center">
            <p className="text-sm font-medium text-muted-foreground">
              {t("templateLabel")}
            </p>
            <h1 className="mt-3 text-4xl font-semibold tracking-tight text-balance sm:text-5xl">
              {t("hero.heading")}
            </h1>
            <p className="mt-4 text-lg text-pretty text-muted-foreground">
              {t("hero.subheading")}
            </p>
            <p className="mt-4 text-sm text-pretty text-muted-foreground">
              {t("bodyLine1")}{" "}
              <code className="rounded bg-muted px-1.5 py-0.5 text-sm">
                {t("bodyAuthSegment")}
              </code>
              {t("bodySuffix")}
            </p>
            <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
              <Button asChild>
                <Link href="/sign-in">{t("hero.cta")}</Link>
              </Button>
            </div>
          </div>
        </section>
      </div>
    </>
  )
}
